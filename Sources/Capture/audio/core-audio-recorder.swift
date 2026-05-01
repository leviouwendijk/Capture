import AudioToolbox
import Foundation

public struct CoreAudioRecorder: Sendable {
    public init() {}

    public func recordAudio(
        configuration: CaptureConfiguration,
        options: CaptureAudioRecordOptions,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureAudioRecordingResult {
        try validateOutput(
            configuration.output
        )

        let resolved = try await CaptureDeviceResolver(
            provider: deviceProvider
        ).resolve(
            configuration: configuration
        )

        let recorder = AudioQueueRecorder(
            device: resolved.audioInput,
            audio: configuration.audio,
            output: configuration.output
        )

        var startedAt = Date()
        var startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

        do {
            try recorder.start()

            startedAt = Date()
            startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

            try await Task.sleep(
                nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000
            )

            try recorder.stop()
        } catch {
            try? recorder.stop()
            throw error
        }

        return CaptureAudioRecordingResult(
            output: configuration.output,
            device: resolved.audioInput,
            durationSeconds: options.durationSeconds,
            startedAt: startedAt,
            startedHostTimeSeconds: startedHostTimeSeconds
        )
    }

    public func recordAudioUntilStopped(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureAudioRecordingResult {
        try validateOutput(
            configuration.output
        )

        let resolved = try await CaptureDeviceResolver(
            provider: deviceProvider
        ).resolve(
            configuration: configuration
        )

        let recorder = AudioQueueRecorder(
            device: resolved.audioInput,
            audio: configuration.audio,
            output: configuration.output
        )

        var startedAt = Date()
        var startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

        do {
            try recorder.start()

            startedAt = Date()
            startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

            await stopSignal.wait()

            try recorder.stop()
        } catch {
            try? recorder.stop()
            throw error
        }

        return CaptureAudioRecordingResult(
            output: configuration.output,
            device: resolved.audioInput,
            durationSeconds: max(
                0,
                Int(
                    Date().timeIntervalSince(
                        startedAt
                    ).rounded()
                )
            ),
            startedAt: startedAt,
            startedHostTimeSeconds: startedHostTimeSeconds
        )
    }
}

internal extension CoreAudioRecorder {
    func validateOutput(
        _ output: URL
    ) throws {
        guard output.pathExtension.localizedCaseInsensitiveCompare(
            "wav"
        ) == .orderedSame else {
            throw CaptureError.audioCapture(
                "Audio-only capture currently writes .wav output."
            )
        }
    }
}
