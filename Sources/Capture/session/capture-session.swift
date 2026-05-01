import AVFoundation
import Foundation

public final class CaptureSession: Sendable {
    public let configuration: CaptureConfiguration
    public let options: CaptureRecordOptions
    public let deviceProvider: any CaptureDeviceProvider
    public let progress: CaptureSessionProgressHandler?

    public init(
        configuration: CaptureConfiguration,
        options: CaptureRecordOptions = .standard,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider(),
        progress: CaptureSessionProgressHandler? = nil
    ) {
        self.configuration = configuration
        self.options = options
        self.deviceProvider = deviceProvider
        self.progress = progress
    }

    @discardableResult
    public func start() async throws -> CaptureRecordingResult {
        let stopSignal = CaptureStopSignal()

        Task {
            try? await Task.sleep(
                nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000
            )

            stopSignal.stop()
        }

        return try await startUntilStopped(
            stopSignal: stopSignal
        )
    }

    @discardableResult
    public func startUntilStopped(
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureRecordingResult {
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "capture-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )

        var shouldRemoveWorkingDirectory = false

        defer {
            if shouldRemoveWorkingDirectory {
                try? FileManager.default.removeItem(
                    at: workingDirectory
                )
            }
        }

        let videoOutput = workingDirectory.appendingPathComponent(
            "video.mov"
        )
        let audioOutput = workingDirectory.appendingPathComponent(
            "audio.wav"
        )
        let systemAudioOutput = workingDirectory.appendingPathComponent(
            "system-audio.m4a"
        )

        let videoConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            systemAudio: configuration.systemAudio,
            audioMix: configuration.audioMix,
            container: .mov,
            output: videoOutput
        )

        let audioConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            systemAudio: configuration.systemAudio,
            audioMix: configuration.audioMix,
            container: .mov,
            output: audioOutput
        )

        let systemAudioConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            systemAudio: configuration.systemAudio,
            audioMix: configuration.audioMix,
            container: .mov,
            output: systemAudioOutput
        )

        async let videoResult = ScreenCaptureVideoRecorder().recordVideoUntilStopped(
            configuration: videoConfiguration,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        )

        async let audioResult = CoreAudioRecorder().recordAudioUntilStopped(
            configuration: audioConfiguration,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        )

        async let systemAudioResult = recordSystemAudioIfNeeded(
            configuration: systemAudioConfiguration,
            stopSignal: stopSignal
        )

        let capturedVideoResult = try await videoResult
        let capturedAudioResult = try await audioResult
        let capturedSystemAudioResult = try await systemAudioResult

        let capturedDurationSeconds = [
            capturedVideoResult.durationSeconds,
            capturedAudioResult.durationSeconds,
            capturedSystemAudioResult?.durationSeconds ?? 0,
        ].max() ?? 0

        await report(
            .recordingStopped(
                durationSeconds: TimeInterval(
                    capturedDurationSeconds
                )
            )
        )

        let videoTimelineStartHostTimeSeconds = capturedVideoResult.firstPresentationTimeSeconds
            ?? capturedVideoResult.startedHostTimeSeconds

        let microphoneStartHostTimeSeconds = capturedAudioResult.firstSampleHostTimeSeconds
            ?? capturedAudioResult.startedHostTimeSeconds

        let microphoneStartOffsetSeconds = normalizedTimelineOffset(
            microphoneStartHostTimeSeconds - videoTimelineStartHostTimeSeconds
        )

        let systemAudioStartOffsetSeconds = capturedSystemAudioResult.map { result in
            let systemAudioStartHostTimeSeconds = result.firstPresentationTimeSeconds
                ?? result.startedHostTimeSeconds

            return normalizedTimelineOffset(
                systemAudioStartHostTimeSeconds - videoTimelineStartHostTimeSeconds
            )
        }

        var audioInputs = [
            CaptureMuxAudioInput(
                url: audioOutput,
                role: .microphone,
                gain: configuration.audioMix.microphoneGain,
                startOffsetSeconds: microphoneStartOffsetSeconds
            ),
        ]

        if capturedSystemAudioResult != nil {
            audioInputs.append(
                CaptureMuxAudioInput(
                    url: systemAudioOutput,
                    role: .system,
                    gain: configuration.audioMix.systemGain,
                    startOffsetSeconds: systemAudioStartOffsetSeconds ?? 0
                )
            )
        }

        let exportMode: CaptureExportMode = configuration.audioMix.requiresAudioRendering
            ? .rendering
            : .passthrough

        await report(
            .exportStarted(
                mode: exportMode
            )
        )

        try await CaptureAssetMuxer().mux(
            video: videoOutput,
            audio: audioInputs,
            audioMix: configuration.audioMix,
            output: configuration.output,
            container: configuration.container
        )

        await report(
            .exportFinished(
                mode: exportMode
            )
        )

        shouldRemoveWorkingDirectory = true

        return CaptureRecordingResult(
            output: configuration.output,
            durationSeconds: capturedDurationSeconds,
            videoFrameCount: capturedVideoResult.frameCount,
            video: capturedVideoResult.video,
            videoDiagnostics: capturedVideoResult.diagnostics,
            audioTrackCount: configuration.audioMix.requiresAudioRendering
                ? 1
                : audioInputs.count,
            audioLayout: configuration.audioMix.requiresAudioRendering
                ? .mixed
                : configuration.audioMix.layout,
            microphoneGain: configuration.audioMix.microphoneGain,
            systemGain: configuration.audioMix.systemGain,
            microphoneStartOffsetSeconds: microphoneStartOffsetSeconds,
            systemAudioStartOffsetSeconds: systemAudioStartOffsetSeconds,
            systemAudioSampleBufferCount: capturedSystemAudioResult?.sampleBufferCount
        )
    }

    public func stop() async throws {
        throw CaptureError.recordingNotImplemented(
            "CaptureSession.stop() is not implemented for externally owned sessions yet."
        )
    }
}

extension CaptureSession {
    internal func normalizedTimelineOffset(
        _ offset: TimeInterval
    ) -> TimeInterval {
        guard offset.isFinite else {
            return 0
        }

        if abs(offset) < 0.010 {
            return 0
        }

        return offset
    }

    internal func report(
        _ event: CaptureSessionProgress
    ) async {
        guard let progress else {
            return
        }

        await progress(
            event
        )
    }

    internal func recordSystemAudioIfNeeded(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureSystemAudioRecordingResult? {
        guard configuration.systemAudio.enabled else {
            return nil
        }

        return try await ScreenCaptureSystemAudioRecorder().recordSystemAudioUntilStopped(
            configuration: configuration,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        )
    }
}
