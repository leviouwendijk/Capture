import Foundation

public final class CameraCaptureSession: Sendable {
    public let configuration: CaptureCameraConfiguration
    public let options: CaptureRecordOptions
    public let deviceProvider: any CaptureDeviceProvider
    public let progress: CaptureSessionProgressHandler?

    public init(
        configuration: CaptureCameraConfiguration,
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
    public func start() async throws -> CaptureCameraRecordingResult {
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
    ) async throws -> CaptureCameraRecordingResult {
        try await CaptureRecordingInstance.execute.attempt(
            prefix: "capture-camera"
        ) { workdir in
            let videoOutput = workdir.appendingPathComponent(
                "camera-video.mov"
            )
            let audioOutput = workdir.appendingPathComponent(
                "audio.wav"
            )

            let videoConfiguration = try CaptureCameraConfiguration(
                camera: configuration.camera,
                video: configuration.video,
                audio: configuration.audio,
                audioMix: configuration.audioMix,
                container: .mov,
                output: videoOutput
            )

            let audioConfiguration = try CaptureConfiguration(
                video: configuration.video,
                audio: configuration.audio,
                output: audioOutput
            )

            await report(
                .recordingStarted(
                    startedAt: Date()
                )
            )

            async let videoResult = CameraVideoRecorder().recordVideoUntilStopped(
                configuration: videoConfiguration,
                stopSignal: stopSignal,
                deviceProvider: deviceProvider
            )

            async let audioResult = CoreAudioRecorder().recordAudioUntilStopped(
                configuration: audioConfiguration,
                stopSignal: stopSignal,
                deviceProvider: deviceProvider
            )

            let capturedVideoResult = try await videoResult
            let capturedAudioResult = try await audioResult

            let capturedDurationSeconds = max(
                capturedVideoResult.durationSeconds,
                capturedAudioResult.durationSeconds
            )

            await report(
                .recordingHealth(
                    snapshot: CaptureRecordingHealthSnapshot(
                        cameraVideoFrameCount: capturedVideoResult.frameCount,
                        videoFrameCount: capturedVideoResult.frameCount
                    )
                )
            )

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

            let audioInputs = [
                CaptureMuxAudioInput(
                    url: audioOutput,
                    role: .microphone,
                    gain: configuration.audioMix.microphoneGain,
                    startOffsetSeconds: microphoneStartOffsetSeconds
                ),
            ]

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

            return CaptureCameraRecordingResult(
                output: configuration.output,
                durationSeconds: capturedDurationSeconds,
                videoFrameCount: capturedVideoResult.frameCount,
                video: capturedVideoResult.video,
                camera: capturedVideoResult.camera,
                audioInput: capturedAudioResult.device,
                audioTrackCount: configuration.audioMix.requiresAudioRendering ? 1 : 1,
                microphoneGain: configuration.audioMix.microphoneGain,
                microphoneStartOffsetSeconds: microphoneStartOffsetSeconds
            )
        }
    }
}

private extension CameraCaptureSession {
    func report(
        _ event: CaptureSessionProgress
    ) async {
        guard let progress else {
            return
        }

        await progress(
            event
        )
    }

    func normalizedTimelineOffset(
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
}
