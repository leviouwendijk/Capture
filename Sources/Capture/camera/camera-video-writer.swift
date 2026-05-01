import AVFoundation
import CoreMedia
import Foundation

internal struct CameraVideoWriterFinishResult {
    let frameCount: Int
    let video: CaptureResolvedVideoOptions
    let firstSampleAt: Date?
    let firstPresentationTimeSeconds: Double?
}

internal final class CameraVideoWriter: @unchecked Sendable {
    private let output: URL
    private let container: CaptureContainer
    private let requestedVideo: CaptureVideoOptions
    private let lock = NSLock()

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var started = false
    private var finished = false
    private var frameCount = 0
    private var resolvedVideo: CaptureResolvedVideoOptions?
    private var firstSampleAt: Date?
    private var firstPresentationTimeSeconds: Double?
    private var lastPresentationTime: CMTime?
    private var failure: Error?

    init(
        output: URL,
        container: CaptureContainer,
        video: CaptureVideoOptions
    ) throws {
        self.output = output
        self.container = container
        self.requestedVideo = video

        try prepareOutput()
    }

    func append(
        _ sampleBuffer: CMSampleBuffer
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !finished,
              failure == nil else {
            return
        }

        guard sampleBuffer.isValid,
              CMSampleBufferDataIsReady(
                sampleBuffer
              ),
              let pixelBuffer = CMSampleBufferGetImageBuffer(
                sampleBuffer
              ) else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(
            sampleBuffer
        )

        guard presentationTime.isValid else {
            return
        }

        do {
            if writer == nil {
                try createWriter(
                    pixelBuffer: pixelBuffer
                )
            }

            guard let writer else {
                throw CaptureError.videoCapture(
                    "Camera video writer is not available."
                )
            }

            if firstSampleAt == nil {
                firstSampleAt = Date()
                firstPresentationTimeSeconds = CMTimeGetSeconds(
                    presentationTime
                )
            }

            if !started {
                guard writer.startWriting() else {
                    failure = writer.error.map(Self.describe)
                        .map(CaptureError.videoCapture)
                        ?? CaptureError.videoCapture(
                            "Could not start camera video writer."
                        )
                    return
                }

                writer.startSession(
                    atSourceTime: presentationTime
                )
                started = true
            }

            guard let input,
                  input.isReadyForMoreMediaData else {
                return
            }

            guard input.append(
                sampleBuffer
            ) else {
                failure = writer.error.map(Self.describe)
                    .map(CaptureError.videoCapture)
                    ?? CaptureError.videoCapture(
                        "Could not append camera video sample buffer."
                    )
                return
            }

            lastPresentationTime = presentationTime
            frameCount += 1
        } catch {
            failure = error
        }
    }

    func fail(
        _ error: Error
    ) {
        lock.lock()
        failure = error
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        finished = true
        writer?.cancelWriting()
        lock.unlock()
    }

    func finish() async throws -> CameraVideoWriterFinishResult {
        let result = try prepareFinish()

        try await finishWriting()

        return result
    }
}

private extension CameraVideoWriter {
    func prepareOutput() throws {
        let directory = output.deletingLastPathComponent()

        if !directory.path.isEmpty {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        if FileManager.default.fileExists(
            atPath: output.path
        ) {
            try FileManager.default.removeItem(
                at: output
            )
        }
    }

    func createWriter(
        pixelBuffer: CVPixelBuffer
    ) throws {
        let width = CVPixelBufferGetWidth(
            pixelBuffer
        )
        let height = CVPixelBufferGetHeight(
            pixelBuffer
        )

        let bitrate = requestedVideo.bitrate
            ?? requestedVideo.quality.recommendedBitrate(
                width: width,
                height: height,
                fps: requestedVideo.fps
            )

        let resolvedVideo = try CaptureResolvedVideoOptions(
            width: width,
            height: height,
            fps: requestedVideo.fps,
            cursor: false,
            codec: requestedVideo.codec,
            quality: requestedVideo.quality,
            bitrate: bitrate
        )

        let writer = try AVAssetWriter(
            outputURL: output,
            fileType: fileType(
                for: container
            )
        )

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings(
                video: resolvedVideo
            )
        )

        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(
            input
        ) else {
            throw CaptureError.videoCapture(
                "Could not add camera video input to asset writer."
            )
        }

        writer.add(
            input
        )

        self.writer = writer
        self.input = input
        self.resolvedVideo = resolvedVideo
    }

    func prepareFinish() throws -> CameraVideoWriterFinishResult {
        lock.lock()

        if let failure {
            finished = true
            writer?.cancelWriting()
            lock.unlock()
            throw failure
        }

        guard started,
              let writer,
              let input,
              let resolvedVideo else {
            finished = true
            self.writer?.cancelWriting()
            lock.unlock()
            throw CaptureError.videoCapture(
                "No camera video frames were captured."
            )
        }

        if let lastPresentationTime {
            writer.endSession(
                atSourceTime: lastPresentationTime
            )
        }

        input.markAsFinished()
        finished = true

        let result = CameraVideoWriterFinishResult(
            frameCount: frameCount,
            video: resolvedVideo,
            firstSampleAt: firstSampleAt,
            firstPresentationTimeSeconds: firstPresentationTimeSeconds
        )

        lock.unlock()

        return result
    }

    func finishWriting() async throws {
        guard let writer else {
            throw CaptureError.videoCapture(
                "Camera video writer is not available."
            )
        }

        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        guard writer.status == .completed else {
            throw writer.error.map(Self.describe)
                .map(CaptureError.videoCapture)
                ?? CaptureError.videoCapture(
                    "Camera video writer did not finish successfully."
                )
        }
    }

    func requireWriter() throws -> AVAssetWriter {
        guard let writer else {
            throw CaptureError.videoCapture(
                "Camera video writer is not available."
            )
        }

        return writer
    }

    func fileType(
        for container: CaptureContainer
    ) -> AVFileType {
        switch container {
        case .mov:
            return .mov

        case .mp4:
            return .mp4
        }
    }

    func videoSettings(
        video: CaptureResolvedVideoOptions
    ) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: video.width,
            AVVideoHeightKey: video.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: video.bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
    }

    static func describe(
        _ error: Error
    ) -> String {
        let nsError = error as NSError

        return "\(nsError.localizedDescription) domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)"
    }
}
