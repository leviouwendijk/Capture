import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

public struct CaptureVideoRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let display: CaptureDevice
    public let durationSeconds: Int
    public let frameCount: Int

    public init(
        output: URL,
        display: CaptureDevice,
        durationSeconds: Int,
        frameCount: Int
    ) {
        self.output = output
        self.display = display
        self.durationSeconds = durationSeconds
        self.frameCount = frameCount
    }
}

public struct ScreenCaptureVideoRecorder: Sendable {
    public init() {}

    public func recordVideo(
        configuration: CaptureConfiguration,
        options: CaptureVideoRecordOptions,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureVideoRecordingResult {
        try validateOutput(
            configuration.output
        )

        try ensureScreenRecordingPermission()

        let resolved = try await CaptureDeviceResolver(
            provider: deviceProvider
        ).resolve(
            configuration: configuration
        )

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first(
            where: {
                String(
                    $0.displayID
                ) == resolved.display.id
            }
        ) else {
            throw CaptureError.deviceNotFound(
                kind: .display,
                value: resolved.display.id
            )
        }

        let filter = SCContentFilter(
            display: display,
            excludingWindows: []
        )

        let streamConfiguration = makeStreamConfiguration(
            video: configuration.video
        )

        let writer = try ScreenCaptureVideoWriter(
            output: configuration.output,
            container: configuration.container,
            video: configuration.video
        )

        let streamOutput = ScreenCaptureVideoStreamOutput(
            writer: writer
        )

        let stream = SCStream(
            filter: filter,
            configuration: streamConfiguration,
            delegate: streamOutput
        )

        try stream.addStreamOutput(
            streamOutput,
            type: .screen,
            sampleHandlerQueue: streamOutput.queue
        )

        do {
            try await stream.startCapture()

            try await Task.sleep(
                nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000
            )

            try await stream.stopCapture()

            let frameCount = try await writer.finish(
                diagnostics: streamOutput.diagnostics()
            )

            return CaptureVideoRecordingResult(
                output: configuration.output,
                display: resolved.display,
                durationSeconds: options.durationSeconds,
                frameCount: frameCount
            )
        } catch {
            try? await stream.stopCapture()
            writer.cancel()
            throw error
        }
    }
}

private extension ScreenCaptureVideoRecorder {
    func validateOutput(
        _ output: URL
    ) throws {
        let ext = output.pathExtension.lowercased()

        guard ext == "mov" || ext == "mp4" else {
            throw CaptureError.videoCapture(
                "Video-only capture currently writes .mov or .mp4 output."
            )
        }
    }

    func ensureScreenRecordingPermission() throws {
        guard CGPreflightScreenCaptureAccess()
                || CGRequestScreenCaptureAccess() else {
            throw CaptureError.videoCapture(
                "Screen Recording permission is not granted to this process. Grant it to the terminal host app, then fully quit and reopen that app."
            )
        }
    }

    func makeStreamConfiguration(
        video: CaptureVideoOptions
    ) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = video.width
        configuration.height = video.height
        configuration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(
                video.fps
            )
        )
        configuration.queueDepth = 5
        configuration.showsCursor = video.cursor
        configuration.capturesAudio = false

        return configuration
    }
}

private final class ScreenCaptureVideoStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    let queue = DispatchQueue(
        label: "capture.screen.video.samples"
    )

    private let writer: ScreenCaptureVideoWriter
    private let lock = NSLock()

    private var totalSampleCount = 0
    private var screenSampleCount = 0
    private var validSampleCount = 0
    private var readySampleCount = 0
    private var appendedFrameCount = 0
    private var stopError: Error?

    init(
        writer: ScreenCaptureVideoWriter
    ) {
        self.writer = writer
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        lock.lock()
        totalSampleCount += 1

        if type == .screen {
            screenSampleCount += 1
        }

        if sampleBuffer.isValid {
            validSampleCount += 1
        }

        if CMSampleBufferDataIsReady(
            sampleBuffer
        ) {
            readySampleCount += 1
        }

        lock.unlock()

        guard type == .screen,
              sampleBuffer.isValid,
              CMSampleBufferDataIsReady(
                sampleBuffer
              ) else {
            return
        }

        let didAppend = writer.append(
            sampleBuffer
        )

        guard didAppend else {
            return
        }

        lock.lock()
        appendedFrameCount += 1
        lock.unlock()
    }

    func stream(
        _ stream: SCStream,
        didStopWithError error: Error
    ) {
        lock.lock()
        stopError = error
        lock.unlock()

        writer.fail(
            error
        )
    }

    func diagnostics() -> String {
        lock.lock()
        let message = """
        stream samples total=\(totalSampleCount) screen=\(screenSampleCount) valid=\(validSampleCount) ready=\(readySampleCount) appended=\(appendedFrameCount) stopError=\(String(describing: stopError))
        """
        lock.unlock()

        return message
    }
}

private final class ScreenCaptureVideoWriter: @unchecked Sendable {
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
        video: CaptureVideoOptions
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
    ) -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !finished,
              failure == nil else {
            return false
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(
            sampleBuffer
        ) else {
            return false
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(
            sampleBuffer
        )

        guard presentationTime.isValid else {
            return false
        }

        if !started {
            guard writer.startWriting() else {
                failure = writer.error.map(Self.describe)
                    .map(CaptureError.videoCapture)
                    ?? CaptureError.videoCapture(
                        "Could not start video writer."
                    )
                return false
            }

            writer.startSession(
                atSourceTime: presentationTime
            )
            started = true
        }

        guard input.isReadyForMoreMediaData else {
            return false
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
            return false
        }

        lastPresentationTime = presentationTime
        frameCount += 1

        return true
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

private extension ScreenCaptureVideoWriter {
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
        video: CaptureVideoOptions
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
        video: CaptureVideoOptions
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
