import Foundation

public final class CameraCaptureSession: Sendable {
    public let configuration: CaptureCameraConfiguration
    public let options: CaptureRecordOptions
    public let workspace: CaptureWorkspaceOptions
    public let deviceProvider: any CaptureDeviceProvider
    public let microphoneChain: AudioChain
    public let progress: CaptureSessionProgressHandler?

    public init(
        configuration: CaptureCameraConfiguration,
        options: CaptureRecordOptions = .standard,
        workspace: CaptureWorkspaceOptions = .standard,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider(),
        microphoneChain: AudioChain = .raw,
        progress: CaptureSessionProgressHandler? = nil
    ) {
        self.configuration = configuration
        self.options = options
        self.workspace = workspace
        self.deviceProvider = deviceProvider
        self.microphoneChain = microphoneChain
        self.progress = progress
    }

    @discardableResult
    public func start() async throws -> CaptureCameraRecordingResult {
        let timedStop = CaptureTimedStopSignal(
            duration: options.duration
        )

        defer {
            timedStop.cancel()
        }

        return try await startUntilStopped(
            stopSignal: timedStop.stopSignal
        )
    }

    @discardableResult
    public func startUntilStopped(
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureCameraRecordingResult {
        try await CaptureRecordingInstance.execute.attempt(
            prefix: "capture-camera",
            workspace: workspace
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

            let cameraReadiness = CaptureReadinessSignal()

            async let videoResult = CameraVideoRecorder().recordVideoUntilStopped(
                configuration: videoConfiguration,
                stopSignal: stopSignal,
                deviceProvider: deviceProvider,
                readiness: cameraReadiness,
                startupRetryPolicy: .cameraDefault
            )

            try await cameraReadiness.wait()

            async let audioResult = CoreAudioRecorder().recordAudioUntilStopped(
                configuration: audioConfiguration,
                stopSignal: stopSignal,
                deviceProvider: deviceProvider,
                chain: microphoneChain
            )

            await report(
                .recordingStarted(
                    startedAt: Date()
                )
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
