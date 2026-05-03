import Foundation

public final class CaptureCompositionSession: Sendable {
    public let configuration: CaptureCompositionConfiguration
    public let options: CaptureRecordOptions
    public let workspace: CaptureWorkspaceOptions
    public let deviceProvider: any CaptureDeviceProvider
    public let microphoneChain: AudioChain
    public let progress: CaptureSessionProgressHandler?

    public init(
        configuration: CaptureCompositionConfiguration,
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
    public func start() async throws -> CaptureCompositionRecordingResult {
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
    ) async throws -> CaptureCompositionRecordingResult {
        try await CaptureRecordingInstance.execute.attempt(
            prefix: "capture-composition",
            workspace: workspace
        ) { workdir in
            let screenVideoOutput = workdir.appendingPathComponent(
                "screen-video.mov"
            )
            let cameraVideoOutput = workdir.appendingPathComponent(
                "camera-video.mov"
            )
            let composedVideoOutput = workdir.appendingPathComponent(
                "composed-video.mov"
            )
            let audioOutput = workdir.appendingPathComponent(
                "audio.wav"
            )
            let systemAudioOutput = workdir.appendingPathComponent(
                "system-audio.m4a"
            )

            let screenVideoConfiguration = try CaptureConfiguration(
                display: configuration.display,
                video: configuration.video,
                audio: configuration.audio,
                systemAudio: configuration.systemAudio,
                audioMix: configuration.audioMix,
                container: .mov,
                output: screenVideoOutput
            )

            let cameraVideoConfiguration = try CaptureCameraConfiguration(
                camera: configuration.camera,
                video: configuration.video,
                audio: configuration.audio,
                audioMix: configuration.audioMix,
                container: .mov,
                output: cameraVideoOutput
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

            let cameraReadiness = CaptureReadinessSignal()

            async let cameraVideoResult = CameraVideoRecorder().recordVideoUntilStopped(
                configuration: cameraVideoConfiguration,
                stopSignal: stopSignal,
                deviceProvider: deviceProvider,
                readiness: cameraReadiness,
                startupRetryPolicy: .cameraDefault
            )

            try await cameraReadiness.wait()

            async let screenMediaResult = ScreenCaptureMediaRecorder().recordMediaUntilStopped(
                configuration: screenVideoConfiguration,
                systemAudioOutput: configuration.systemAudio.enabled
                    ? systemAudioOutput
                    : nil,
                stopSignal: stopSignal,
                deviceProvider: deviceProvider
            )

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

            let capturedScreenMediaResult = try await screenMediaResult
            let capturedScreenVideoResult = capturedScreenMediaResult.video
            let capturedCameraVideoResult = try await cameraVideoResult
            let capturedAudioResult = try await audioResult
            let capturedSystemAudioResult = capturedScreenMediaResult.systemAudio

            let capturedDurationSeconds = [
                capturedScreenVideoResult.durationSeconds,
                capturedCameraVideoResult.durationSeconds,
                capturedAudioResult.durationSeconds,
                capturedSystemAudioResult?.durationSeconds ?? 0,
            ].max() ?? 0

            await report(
                .recordingHealth(
                    snapshot: CaptureRecordingHealthSnapshot(
                        screenVideoFrameCount: capturedScreenVideoResult.frameCount,
                        cameraVideoFrameCount: capturedCameraVideoResult.frameCount,
                        videoMissedFrameBudget: capturedScreenVideoResult.diagnostics.targetFrameShortfall,
                        videoAppendSkipCount: capturedScreenVideoResult.diagnostics.appendSkipCount,
                        videoDroppedFrameCount: capturedScreenVideoResult.diagnostics.droppedFrameCount,
                        systemAudioEnabled: configuration.systemAudio.enabled,
                        systemAudioSampleBufferCount: capturedSystemAudioResult?.sampleBufferCount
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

            let screenVideoStartHostTimeSeconds = capturedScreenVideoResult.firstPresentationTimeSeconds
                ?? capturedScreenVideoResult.startedHostTimeSeconds
            let cameraVideoStartHostTimeSeconds = capturedCameraVideoResult.firstPresentationTimeSeconds
                ?? capturedCameraVideoResult.startedHostTimeSeconds

            let videoTimelineStartHostTimeSeconds = earliestHostTime(
                [
                    screenVideoStartHostTimeSeconds,
                    cameraVideoStartHostTimeSeconds,
                ]
            )

            let screenVideoStartOffsetSeconds = normalizedTimelineOffset(
                screenVideoStartHostTimeSeconds - videoTimelineStartHostTimeSeconds
            )

            let cameraVideoStartOffsetSeconds = normalizedTimelineOffset(
                cameraVideoStartHostTimeSeconds - videoTimelineStartHostTimeSeconds
            )

            await report(
                .exportStarted(
                    mode: .rendering
                )
            )

            let composedVideoResult = try await CaptureCompositionVideoRenderer().render(
                inputs: [
                    CaptureCompositionVideoInput(
                        source: .screen,
                        url: screenVideoOutput,
                        startOffsetSeconds: screenVideoStartOffsetSeconds
                    ),
                    CaptureCompositionVideoInput(
                        source: .camera,
                        url: cameraVideoOutput,
                        startOffsetSeconds: cameraVideoStartOffsetSeconds
                    ),
                ],
                layout: configuration.layout,
                video: capturedScreenVideoResult.video,
                output: composedVideoOutput,
                container: .mov
            )

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

            try await CaptureAssetMuxer().mux(
                video: composedVideoOutput,
                audio: audioInputs,
                audioMix: configuration.audioMix,
                output: configuration.output,
                container: configuration.container
            )

            await report(
                .exportFinished(
                    mode: .rendering
                )
            )

            return CaptureCompositionRecordingResult(
                output: configuration.output,
                durationSeconds: composedVideoResult.durationSeconds,
                video: composedVideoResult.video,
                screenFrameCount: capturedScreenVideoResult.frameCount,
                screenVideoDiagnostics: capturedScreenVideoResult.diagnostics,
                cameraFrameCount: capturedCameraVideoResult.frameCount,
                audioTrackCount: configuration.audioMix.requiresAudioRendering
                    ? 1
                    : audioInputs.count,
                audioLayout: configuration.audioMix.requiresAudioRendering
                    ? .mixed
                    : configuration.audioMix.layout,
                microphoneGain: configuration.audioMix.microphoneGain,
                systemGain: configuration.audioMix.systemGain,
                microphoneStartOffsetSeconds: microphoneStartOffsetSeconds,
                systemAudioStartOffsetSeconds: systemAudioStartOffsetSeconds
            )
        }
    }
}

private extension CaptureCompositionSession {
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

    func earliestHostTime(
        _ values: [TimeInterval]
    ) -> TimeInterval {
        values
            .filter(\.isFinite)
            .min() ?? CaptureClock.hostTimeSeconds()
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
