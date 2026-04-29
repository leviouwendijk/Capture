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
    public let video: CaptureResolvedVideoOptions
    public let diagnostics: CaptureVideoRecordingDiagnostics

    public init(
        output: URL,
        display: CaptureDevice,
        durationSeconds: Int,
        frameCount: Int,
        video: CaptureResolvedVideoOptions,
        diagnostics: CaptureVideoRecordingDiagnostics
    ) {
        self.output = output
        self.display = display
        self.durationSeconds = durationSeconds
        self.frameCount = frameCount
        self.video = video
        self.diagnostics = diagnostics
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

        let resolvedVideo = try configuration.video.resolved(
            displaySize: displaySize(
                for: display
            )
        )

        let filter = SCContentFilter(
            display: display,
            excludingWindows: []
        )

        let streamConfiguration = makeStreamConfiguration(
            video: resolvedVideo
        )

        let writer = try ScreenCaptureVideoWriter(
            output: configuration.output,
            container: configuration.container,
            video: resolvedVideo
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

        var streamDidStart = false
        let startedAt = Date()

        do {
            try await stream.startCapture()
            streamDidStart = true

            try await Task.sleep(
                nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000
            )

            try await stopStreamAllowingAlreadyStopped(
                stream
            )
            streamDidStart = false

            let recordedSeconds = Date().timeIntervalSince(
                startedAt
            )
            let frameCount = try await writer.finish(
                diagnostics: streamOutput.diagnostics(
                    requestedFramesPerSecond: resolvedVideo.fps,
                    recordedSeconds: recordedSeconds,
                    finishedFrameCount: nil
                ).summary
            )
            let diagnostics = streamOutput.diagnostics(
                requestedFramesPerSecond: resolvedVideo.fps,
                recordedSeconds: recordedSeconds,
                finishedFrameCount: frameCount
            )

            return CaptureVideoRecordingResult(
                output: configuration.output,
                display: resolved.display,
                durationSeconds: max(
                    0,
                    Int(
                        recordedSeconds.rounded()
                    )
                ),
                frameCount: frameCount,
                video: resolvedVideo,
                diagnostics: diagnostics
            )
        } catch {
            if streamDidStart {
                try? await stopStreamAllowingAlreadyStopped(
                    stream
                )
            }

            writer.cancel()
            throw error
        }
    }

    public func recordVideoUntilStopped(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
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

        let resolvedVideo = try configuration.video.resolved(
            displaySize: displaySize(
                for: display
            )
        )

        let filter = SCContentFilter(
            display: display,
            excludingWindows: []
        )

        let streamConfiguration = makeStreamConfiguration(
            video: resolvedVideo
        )

        let writer = try ScreenCaptureVideoWriter(
            output: configuration.output,
            container: configuration.container,
            video: resolvedVideo
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

        let startedAt = Date()
        var streamDidStart = false

        do {
            try await stream.startCapture()
            streamDidStart = true

            await stopSignal.wait()

            try await stopStreamAllowingAlreadyStopped(
                stream
            )
            streamDidStart = false

            let recordedSeconds = Date().timeIntervalSince(
                startedAt
            )
            let frameCount = try await writer.finish(
                diagnostics: streamOutput.diagnostics(
                    requestedFramesPerSecond: resolvedVideo.fps,
                    recordedSeconds: recordedSeconds,
                    finishedFrameCount: nil
                ).summary
            )
            let diagnostics = streamOutput.diagnostics(
                requestedFramesPerSecond: resolvedVideo.fps,
                recordedSeconds: recordedSeconds,
                finishedFrameCount: frameCount
            )

            return CaptureVideoRecordingResult(
                output: configuration.output,
                display: resolved.display,
                durationSeconds: max(
                    0,
                    Int(
                        recordedSeconds.rounded()
                    )
                ),
                frameCount: frameCount,
                video: resolvedVideo,
                diagnostics: diagnostics
            )
        } catch {
            if streamDidStart {
                try? await stopStreamAllowingAlreadyStopped(
                    stream
                )
            }

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

    func displaySize(
        for display: SCDisplay
    ) -> CaptureVideoSize {
        CaptureVideoSize(
            width: display.width,
            height: display.height
        )
    }

    func makeStreamConfiguration(
        video: CaptureResolvedVideoOptions
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

    func stopStreamAllowingAlreadyStopped(
        _ stream: SCStream
    ) async throws {
        do {
            try await stream.stopCapture()
        } catch {
            guard isAlreadyStoppedStreamError(
                error
            ) else {
                throw error
            }
        }
    }

    func isAlreadyStoppedStreamError(
        _ error: Error
    ) -> Bool {
        let message = (error as NSError).localizedDescription

        return message.localizedCaseInsensitiveContains(
            "already stopped"
        )
    }
}

private enum ScreenCaptureFrameSampleStatus: Sendable, Hashable {
    case complete
    case incomplete(rawValue: Int)
    case missing
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
    private var completeFrameStatusCount = 0
    private var incompleteFrameStatusCount = 0
    private var missingFrameStatusCount = 0
    private var frameStatusRawValueCounts: [Int: Int] = [:]
    private var appendedFrameCount = 0
    private var writerNotReadyFrameCount = 0
    private var missingPixelBufferFrameCount = 0
    private var invalidPresentationTimeFrameCount = 0
    private var appendFailedFrameCount = 0
    private var skippedAfterFinishedFrameCount = 0
    private var skippedAfterFailureFrameCount = 0
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
        recordSample(
            sampleBuffer: sampleBuffer,
            type: type
        )

        guard type == .screen,
              sampleBuffer.isValid,
              CMSampleBufferDataIsReady(
                sampleBuffer
              ) else {
            return
        }

        switch frameStatus(
            for: sampleBuffer
        ) {
        case .complete:
            recordCompleteFrameStatus()

        case .incomplete(let rawValue):
            recordIncompleteFrameStatus(
                rawValue: rawValue
            )
            return

        case .missing:
            recordMissingFrameStatus()
            return
        }

        switch writer.append(
            sampleBuffer
        ) {
        case .appended:
            lock.lock()
            appendedFrameCount += 1
            lock.unlock()

        case .skipped(let reason):
            recordSkippedAppend(
                reason
            )
        }
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

    func diagnostics(
        requestedFramesPerSecond: Int,
        recordedSeconds: TimeInterval,
        finishedFrameCount: Int?
    ) -> CaptureVideoRecordingDiagnostics {
        lock.lock()

        let diagnostics = CaptureVideoRecordingDiagnostics(
            requestedFramesPerSecond: requestedFramesPerSecond,
            recordedSeconds: recordedSeconds,
            totalSampleCount: totalSampleCount,
            screenSampleCount: screenSampleCount,
            validSampleCount: validSampleCount,
            readySampleCount: readySampleCount,
            completeFrameStatusCount: completeFrameStatusCount,
            incompleteFrameStatusCount: incompleteFrameStatusCount,
            missingFrameStatusCount: missingFrameStatusCount,
            frameStatusRawValueCounts: frameStatusRawValueCounts,
            appendedFrameCount: appendedFrameCount,
            finishedFrameCount: finishedFrameCount ?? appendedFrameCount,
            writerNotReadyFrameCount: writerNotReadyFrameCount,
            missingPixelBufferFrameCount: missingPixelBufferFrameCount,
            invalidPresentationTimeFrameCount: invalidPresentationTimeFrameCount,
            appendFailedFrameCount: appendFailedFrameCount,
            skippedAfterFinishedFrameCount: skippedAfterFinishedFrameCount,
            skippedAfterFailureFrameCount: skippedAfterFailureFrameCount,
            stopErrorDescription: stopError.map {
                ($0 as NSError).localizedDescription
            }
        )

        lock.unlock()

        return diagnostics
    }
}

private extension ScreenCaptureVideoStreamOutput {
    func recordSample(
        sampleBuffer: CMSampleBuffer,
        type: SCStreamOutputType
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
    }

    func frameStatus(
        for sampleBuffer: CMSampleBuffer
    ) -> ScreenCaptureFrameSampleStatus {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first,
              let rawValue = attachments[
                SCStreamFrameInfo.status
              ] as? Int else {
            return .missing
        }

        guard let status = SCFrameStatus(
            rawValue: rawValue
        ),
              status == .complete else {
            return .incomplete(
                rawValue: rawValue
            )
        }

        return .complete
    }

    func recordCompleteFrameStatus() {
        lock.lock()
        completeFrameStatusCount += 1
        lock.unlock()
    }

    func recordIncompleteFrameStatus(
        rawValue: Int
    ) {
        lock.lock()
        incompleteFrameStatusCount += 1
        frameStatusRawValueCounts[
            rawValue,
            default: 0
        ] += 1
        lock.unlock()
    }

    func recordMissingFrameStatus() {
        lock.lock()
        missingFrameStatusCount += 1
        lock.unlock()
    }

    func recordSkippedAppend(
        _ reason: ScreenCaptureVideoAppendSkipReason
    ) {
        lock.lock()

        switch reason {
        case .finished:
            skippedAfterFinishedFrameCount += 1

        case .failed:
            skippedAfterFailureFrameCount += 1

        case .missingPixelBuffer:
            missingPixelBufferFrameCount += 1

        case .invalidPresentationTime:
            invalidPresentationTimeFrameCount += 1

        case .writerNotReady:
            writerNotReadyFrameCount += 1

        case .appendFailed:
            appendFailedFrameCount += 1
        }

        lock.unlock()
    }
}

private enum ScreenCaptureVideoAppendResult: Sendable, Hashable {
    case appended
    case skipped(ScreenCaptureVideoAppendSkipReason)
}

private enum ScreenCaptureVideoAppendSkipReason: String, Sendable, Codable, Hashable {
    case finished
    case failed
    case missingPixelBuffer
    case invalidPresentationTime
    case writerNotReady
    case appendFailed
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
