import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit

public struct CaptureSystemAudioRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let sampleBufferCount: Int
    public let startedAt: Date
    public let firstSampleAt: Date?
    public let firstPresentationTimeSeconds: Double?

    public init(
        output: URL,
        durationSeconds: Int,
        sampleBufferCount: Int,
        startedAt: Date,
        firstSampleAt: Date?,
        firstPresentationTimeSeconds: Double?
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.sampleBufferCount = sampleBufferCount
        self.startedAt = startedAt
        self.firstSampleAt = firstSampleAt
        self.firstPresentationTimeSeconds = firstPresentationTimeSeconds
    }
}

public struct ScreenCaptureSystemAudioRecorder: Sendable {
    public init() {}

    public func recordSystemAudioUntilStopped(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureSystemAudioRecordingResult {
        guard configuration.systemAudio.enabled else {
            throw CaptureError.audioCapture(
                "System audio capture is not enabled."
            )
        }

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
            systemAudio: configuration.systemAudio
        )

        let writer = try ScreenCaptureSystemAudioWriter(
            output: configuration.output,
            systemAudio: configuration.systemAudio
        )

        let streamOutput = ScreenCaptureSystemAudioStreamOutput(
            writer: writer
        )

        let stream = SCStream(
            filter: filter,
            configuration: streamConfiguration,
            delegate: streamOutput
        )

        try stream.addStreamOutput(
            streamOutput,
            type: .audio,
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

            let duration = Date().timeIntervalSince(
                startedAt
            )

            let finishResult = try await writer.finish()

            return CaptureSystemAudioRecordingResult(
                output: configuration.output,
                durationSeconds: max(
                    0,
                    Int(
                        duration.rounded()
                    )
                ),
                sampleBufferCount: finishResult.sampleBufferCount,
                startedAt: startedAt,
                firstSampleAt: finishResult.firstSampleAt,
                firstPresentationTimeSeconds: finishResult.firstPresentationTimeSeconds
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

private extension ScreenCaptureSystemAudioRecorder {
    func ensureScreenRecordingPermission() throws {
        guard CGPreflightScreenCaptureAccess()
                || CGRequestScreenCaptureAccess() else {
            throw CaptureError.audioCapture(
                "Screen Recording permission is not granted to this process. Grant it to the terminal host app, then fully quit and reopen that app."
            )
        }
    }

    func makeStreamConfiguration(
        systemAudio: CaptureSystemAudioOptions
    ) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.sampleRate = systemAudio.sampleRate
        configuration.channelCount = systemAudio.channelCount
        configuration.excludesCurrentProcessAudio = systemAudio.excludesCurrentProcessAudio

        return configuration
    }

    func stopStreamAllowingAlreadyStopped(
        _ stream: SCStream
    ) async throws {
        do {
            try await stream.stopCapture()
        } catch {
            let message = (error as NSError).localizedDescription

            guard message.localizedCaseInsensitiveContains(
                "already stopped"
            ) else {
                throw error
            }
        }
    }
}

private final class ScreenCaptureSystemAudioStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    let queue = DispatchQueue(
        label: "capture.system-audio.samples"
    )

    private let writer: ScreenCaptureSystemAudioWriter
    private let lock = NSLock()

    private var stopError: Error?

    init(
        writer: ScreenCaptureSystemAudioWriter
    ) {
        self.writer = writer
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio,
              sampleBuffer.isValid,
              CMSampleBufferDataIsReady(
                sampleBuffer
              ) else {
            return
        }

        writer.append(
            sampleBuffer
        )
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
}

private struct ScreenCaptureSystemAudioWriterFinishResult {
    let sampleBufferCount: Int
    let firstSampleAt: Date?
    let firstPresentationTimeSeconds: Double?
}

private final class ScreenCaptureSystemAudioWriter: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let lock = NSLock()

    private var started = false
    private var finished = false
    private var sampleBufferCount = 0
    private var firstSampleAt: Date?
    private var firstPresentationTimeSeconds: Double?
    private var lastPresentationTime: CMTime?
    private var failure: Error?

    init(
        output: URL,
        systemAudio: CaptureSystemAudioOptions
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

        writer = try AVAssetWriter(
            outputURL: output,
            fileType: .m4a
        )

        input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: systemAudio.sampleRate,
                AVNumberOfChannelsKey: systemAudio.channelCount,
                AVEncoderBitRateKey: 192_000,
            ]
        )

        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(
            input
        ) else {
            throw CaptureError.audioCapture(
                "Could not add system audio input to asset writer."
            )
        }

        writer.add(
            input
        )
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

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(
            sampleBuffer
        )

        guard presentationTime.isValid else {
            return
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
                    .map(CaptureError.audioCapture)
                    ?? CaptureError.audioCapture(
                        "Could not start system audio writer."
                    )
                return
            }

            writer.startSession(
                atSourceTime: presentationTime
            )
            started = true
        }

        guard input.isReadyForMoreMediaData else {
            return
        }

        guard input.append(
            sampleBuffer
        ) else {
            failure = writer.error.map(Self.describe)
                .map(CaptureError.audioCapture)
                ?? CaptureError.audioCapture(
                    "Could not append system audio sample buffer."
                )
            return
        }

        lastPresentationTime = presentationTime
        sampleBufferCount += 1
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

    func finish() async throws -> ScreenCaptureSystemAudioWriterFinishResult {
        let result = try prepareFinish()

        try await finishWriting()

        return result
    }
}

private extension ScreenCaptureSystemAudioWriter {
    func prepareFinish() throws -> ScreenCaptureSystemAudioWriterFinishResult {
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
            throw CaptureError.audioCapture(
                "No system audio samples were captured."
            )
        }

        if let lastPresentationTime {
            writer.endSession(
                atSourceTime: lastPresentationTime
            )
        }

        input.markAsFinished()
        finished = true

        let result = ScreenCaptureSystemAudioWriterFinishResult(
            sampleBufferCount: sampleBufferCount,
            firstSampleAt: firstSampleAt,
            firstPresentationTimeSeconds: firstPresentationTimeSeconds
        )

        lock.unlock()

        return result
    }

    func finishWriting() async throws {
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        guard writer.status == .completed else {
            throw writer.error.map(Self.describe)
                .map(CaptureError.audioCapture)
                ?? CaptureError.audioCapture(
                    "System audio writer did not finish successfully."
                )
        }
    }

    static func describe(
        _ error: Error
    ) -> String {
        let nsError = error as NSError

        return "\(nsError.localizedDescription) domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)"
    }
}
