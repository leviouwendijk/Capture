import Foundation

public final class CaptureCompositionSession: Sendable {
    public let configuration: CaptureCompositionConfiguration
    public let options: CaptureRecordOptions
    public let deviceProvider: any CaptureDeviceProvider
    public let progress: CaptureSessionProgressHandler?

    public init(
        configuration: CaptureCompositionConfiguration,
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
    public func start() async throws -> CaptureCompositionRecordingResult {
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
    ) async throws -> CaptureCompositionRecordingResult {
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "capture-composition-\(UUID().uuidString)",
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

        do {
            let screenVideoOutput = workingDirectory.appendingPathComponent(
                "screen-video.mov"
            )
            let cameraVideoOutput = workingDirectory.appendingPathComponent(
                "camera-video.mov"
            )
            let composedVideoOutput = workingDirectory.appendingPathComponent(
                "composed-video.mov"
            )
            let audioOutput = workingDirectory.appendingPathComponent(
                "audio.wav"
            )
            let systemAudioOutput = workingDirectory.appendingPathComponent(
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

            let systemAudioConfiguration = try CaptureConfiguration(
                display: configuration.display,
                video: configuration.video,
                audio: configuration.audio,
                systemAudio: configuration.systemAudio,
                audioMix: configuration.audioMix,
                container: .mov,
                output: systemAudioOutput
            )

            async let screenVideoResult = ScreenCaptureVideoRecorder().recordVideoUntilStopped(
                configuration: screenVideoConfiguration,
                stopSignal: stopSignal,
                deviceProvider: deviceProvider
            )

            async let cameraVideoResult = CameraVideoRecorder().recordVideoUntilStopped(
                configuration: cameraVideoConfiguration,
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

            let capturedScreenVideoResult = try await screenVideoResult
            let capturedCameraVideoResult = try await cameraVideoResult
            let capturedAudioResult = try await audioResult
            let capturedSystemAudioResult = try await systemAudioResult

            let capturedDurationSeconds = [
                capturedScreenVideoResult.durationSeconds,
                capturedCameraVideoResult.durationSeconds,
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

            shouldRemoveWorkingDirectory = true

            return CaptureCompositionRecordingResult(
                output: configuration.output,
                durationSeconds: composedVideoResult.durationSeconds,
                video: composedVideoResult.video,
                screenFrameCount: capturedScreenVideoResult.frameCount,
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
        } catch {
            throw CapturePartialRecordingError(
                workingDirectory: workingDirectory,
                underlyingError: error
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

    // func earliestDate(
    //     _ dates: [Date]
    // ) -> Date {
    //     dates.min() ?? Date()
    // }

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

    func recordSystemAudioIfNeeded(
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
