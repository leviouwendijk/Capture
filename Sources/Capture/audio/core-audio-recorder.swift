import Foundation

public struct CoreAudioRecorder: Sendable {
    public init() {}

    public func recordAudio(
        configuration: CaptureConfiguration,
        options: CaptureAudioRecordOptions,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider(),
        chain: Audio.Chain = .raw
    ) async throws -> CaptureAudioRecordingResult {
        try validateOutput(
            configuration.output
        )

        let resolved = try await CaptureDeviceResolver(
            provider: deviceProvider
        ).resolve(
            configuration: configuration
        )

        let recording = CoreAudioWAVRecordingPipeline(
            device: resolved.audioInput,
            audio: configuration.audio,
            output: configuration.output,
            chain: chain
        )

        var startedAt = Date()
        var startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

        do {
            try recording.start()

            startedAt = Date()
            startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

            try await Task.sleep(
                nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000
            )

            try recording.stop()
        } catch {
            recording.cancel()
            throw error
        }

        return CaptureAudioRecordingResult(
            output: configuration.output,
            device: resolved.audioInput,
            durationSeconds: options.durationSeconds,
            startedAt: startedAt,
            startedHostTimeSeconds: startedHostTimeSeconds,
            firstSampleHostTimeSeconds: recording.firstSampleHostTimeSeconds()
        )
    }

    public func recordAudioUntilStopped(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider(),
        chain: Audio.Chain = .raw
    ) async throws -> CaptureAudioRecordingResult {
        try validateOutput(
            configuration.output
        )

        let resolved = try await CaptureDeviceResolver(
            provider: deviceProvider
        ).resolve(
            configuration: configuration
        )

        let recording = CoreAudioWAVRecordingPipeline(
            device: resolved.audioInput,
            audio: configuration.audio,
            output: configuration.output,
            chain: chain
        )

        var startedAt = Date()
        var startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

        do {
            try recording.start()

            startedAt = Date()
            startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

            await stopSignal.wait()

            try recording.stop()
        } catch {
            recording.cancel()
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
            startedHostTimeSeconds: startedHostTimeSeconds,
            firstSampleHostTimeSeconds: recording.firstSampleHostTimeSeconds()
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

internal final class CoreAudioWAVRecordingPipeline: @unchecked Sendable {
    private let sink: any CaptureAudioSink
    private let stream: CoreAudioInputStream

    internal init(
        device: CaptureDevice,
        audio: CaptureAudioOptions,
        output: URL,
        chain: Audio.Chain = .raw
    ) {
        let wav = WAVAudioSink(
            output: output
        )
        let sink: any CaptureAudioSink = chain.isEmpty
            ? wav
            : ChainAudioSink(
                downstream: wav,
                chain: chain
            )

        self.sink = sink
        self.stream = CoreAudioInputStream(
            device: device,
            audio: audio,
            startHandler: { format in
                try sink.start(
                    format: format
                )
            },
            bufferHandler: { buffer in
                try sink.append(
                    buffer
                )
            }
        )
    }

    internal func start() throws {
        do {
            try stream.start()
        } catch {
            sink.cancel()
            throw error
        }
    }

    internal func stop() throws {
        var capturedError: Error?

        do {
            try stream.stop()
        } catch {
            capturedError = error
        }

        do {
            try sink.finish()
        } catch {
            if capturedError == nil {
                capturedError = error
            }
        }

        if let capturedError {
            throw capturedError
        }
    }

    internal func cancel() {
        try? stream.stop()

        sink.cancel()
    }

    internal func firstSampleHostTimeSeconds() -> TimeInterval? {
        stream.firstSampleHostTimeSeconds()
    }
}
