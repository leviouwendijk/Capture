import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

internal final class ScreenCaptureVideoWriter: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let lock = NSLock()

    private var started = false
    private var finished = false
    private var frameCount = 0
    private var lastPresentationTime: CMTime?
    private var failure: Error?

    init(
        output: URL,
        container: CaptureContainer,
        video: CaptureResolvedVideoOptions
    ) throws {
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

        self.writer = try AVAssetWriter(
            outputURL: output,
            fileType: Self.fileType(
                for: container
            )
        )

        self.input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: Self.videoSettings(
                video: video
            )
        )

        self.input.expectsMediaDataInRealTime = true

        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: Self.pixelBufferAttributes(
                video: video
            )
        )

        guard writer.canAdd(
            input
        ) else {
            throw CaptureError.videoCapture(
                "Could not add video input to asset writer."
            )
        }

        writer.add(
            input
        )
    }

    func append(
        _ sampleBuffer: CMSampleBuffer
    ) -> ScreenCaptureVideoAppendResult {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !finished else {
            return .skipped(
                .finished
            )
        }

        guard failure == nil else {
            return .skipped(
                .failed
            )
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(
            sampleBuffer
        ) else {
            return .skipped(
                .missingPixelBuffer
            )
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(
            sampleBuffer
        )

        guard presentationTime.isValid else {
            return .skipped(
                .invalidPresentationTime
            )
        }

        if !started {
            guard writer.startWriting() else {
                failure = writer.error.map(Self.describe)
                    .map(CaptureError.videoCapture)
                    ?? CaptureError.videoCapture(
                        "Could not start video writer."
                    )

                return .skipped(
                    .appendFailed
                )
            }

            writer.startSession(
                atSourceTime: presentationTime
            )
            started = true
        }

        guard input.isReadyForMoreMediaData else {
            return .skipped(
                .writerNotReady
            )
        }

        guard adaptor.append(
            pixelBuffer,
            withPresentationTime: presentationTime
        ) else {
            failure = writer.error.map(Self.describe)
                .map(CaptureError.videoCapture)
                ?? CaptureError.videoCapture(
                    "Could not append video pixel buffer."
                )

            return .skipped(
                .appendFailed
            )
        }

        lastPresentationTime = presentationTime
        frameCount += 1

        return .appended
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
        writer.cancelWriting()
        lock.unlock()
    }

    func finish(
        diagnostics: String
    ) async throws -> Int {
        let capturedFrameCount = try prepareFinish(
            diagnostics: diagnostics
        )

        try await finishWriting()

        return capturedFrameCount
    }

    private func prepareFinish(
        diagnostics: String
    ) throws -> Int {
        lock.lock()

        if let failure {
            finished = true
            writer.cancelWriting()
            lock.unlock()
            throw failure
        }

        guard started else {
            finished = true
            writer.cancelWriting()
            lock.unlock()
            throw CaptureError.videoCapture(
                "No video frames were captured. \(diagnostics)."
            )
        }

        if let lastPresentationTime {
            writer.endSession(
                atSourceTime: lastPresentationTime
            )
        }

        input.markAsFinished()
        finished = true

        let capturedFrameCount = frameCount

        lock.unlock()

        return capturedFrameCount
    }
}

internal extension ScreenCaptureVideoWriter {
    static func fileType(
        for container: CaptureContainer
    ) -> AVFileType {
        switch container {
        case .mov:
            return .mov

        case .mp4:
            return .mp4
        }
    }

    static func videoSettings(
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

    static func pixelBufferAttributes(
        video: CaptureResolvedVideoOptions
    ) -> [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: video.width,
            kCVPixelBufferHeightKey as String: video.height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
    }

    static func describe(
        _ error: Error
    ) -> String {
        let nsError = error as NSError

        return "\(nsError.localizedDescription) domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)"
    }

    func finishWriting() async throws {
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        guard writer.status == .completed else {
            throw writer.error.map(Self.describe)
                .map(CaptureError.videoCapture)
                ?? CaptureError.videoCapture(
                    "Video writer did not finish successfully."
                )
        }
    }
}
