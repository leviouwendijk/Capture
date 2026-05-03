import AVFoundation
import CoreMedia
import Foundation

public struct CameraVideoRecorder: Sendable {
    public init() {}

    public func recordVideoUntilStopped(
        configuration: CaptureCameraConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureCameraVideoRecordingResult {
        try await recordVideoUntilStopped(
            configuration: configuration,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider,
            readiness: nil,
            startupRetryPolicy: .cameraDefault
        )
    }
}

internal extension CameraVideoRecorder {
    func recordVideoUntilStopped(
        configuration: CaptureCameraConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider(),
        readiness: CaptureReadinessSignal?,
        startupRetryPolicy: CaptureStartupRetryPolicy = .cameraDefault
    ) async throws -> CaptureCameraVideoRecordingResult {
        try validateOutput(
            configuration.output
        )

        try await ensureCameraPermission()

        let attempts = max(
            1,
            startupRetryPolicy.attempts
        )

        var lastFailure: Error?

        for attempt in 1...attempts {
            guard !stopSignal.isTriggered else {
                let error = CaptureError.videoCapture(
                    "Camera startup was stopped before \(describe(configuration.camera)) became ready."
                )

                readiness?.fail(
                    error
                )

                throw error
            }

            do {
                return try await recordVideoAttemptUntilStopped(
                    configuration: configuration,
                    stopSignal: stopSignal,
                    deviceProvider: deviceProvider,
                    readiness: readiness
                )
            } catch let failure as CameraVideoAttemptFailure {
                lastFailure = failure.underlyingError

                if failure.happenedAfterReadiness || attempt == attempts {
                    let error = failure.happenedAfterReadiness
                        ? failure.underlyingError
                        : CaptureError.videoCapture(
                            "Camera startup failed after \(attempts) attempt(s). Last failure: \(describe(failure.underlyingError))"
                        )

                    readiness?.fail(
                        error
                    )

                    throw error
                }

                if startupRetryPolicy.delayNanoseconds > 0 {
                    try await Task.sleep(
                        nanoseconds: startupRetryPolicy.delayNanoseconds
                    )
                }
            } catch {
                readiness?.fail(
                    error
                )

                throw error
            }
        }

        let error = CaptureError.videoCapture(
            "Camera startup failed after \(attempts) attempt(s). Last failure: \(lastFailure.map(describe) ?? "unknown")."
        )

        readiness?.fail(
            error
        )

        throw error
    }
}

private struct CameraVideoAttemptFailure: Error {
    let underlyingError: Error
    let happenedAfterReadiness: Bool

    init(
        underlyingError: Error,
        happenedAfterReadiness: Bool
    ) {
        self.underlyingError = underlyingError
        self.happenedAfterReadiness = happenedAfterReadiness
    }
}

private extension CameraVideoRecorder {
    func recordVideoAttemptUntilStopped(
        configuration: CaptureCameraConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider,
        readiness: CaptureReadinessSignal?
    ) async throws -> CaptureCameraVideoRecordingResult {
        let resolved = try await CameraCaptureDeviceResolver(
            provider: deviceProvider
        ).resolve(
            configuration: configuration
        )

        let cameraDevice = try cameraDevice(
            matching: resolved.videoInput
        )

        let sink = try SegmentedCameraVideoSink(
            output: configuration.output,
            container: configuration.container,
            video: configuration.video
        )

        let recordingState = CameraRecordingState()

        let streamOutput = CameraVideoStreamOutput(
            sink: sink
        ) { error in
            sink.fail(
                error
            )

            if recordingState.isReady {
                stopSignal.stop()
            }
        }

        let session = AVCaptureSession()
        let videoOutput = AVCaptureVideoDataOutput()

        var runtimeObserver: CameraCaptureRuntimeObserver?
        var livenessTask: Task<Void, Never>?

        do {
            try configure(
                session: session,
                cameraDevice: cameraDevice,
                videoOutput: videoOutput,
                streamOutput: streamOutput,
                fps: configuration.video.fps
            )

            runtimeObserver = CameraCaptureRuntimeObserver(
                session: session,
                deviceName: resolved.videoInput.name
            ) { error in
                sink.fail(
                    error
                )

                if recordingState.isReady {
                    stopSignal.stop()
                }
            }

            session.startRunning()

            guard session.isRunning else {
                throw CaptureError.videoCapture(
                    "Camera capture session did not start for \(resolved.videoInput.name)."
                )
            }

            _ = try await streamOutput.waitForStableRecording(
                timeoutSeconds: 8,
                minimumWrittenFrameCount: stableStartupFrameCount(
                    fps: configuration.video.fps
                ),
                deviceName: resolved.videoInput.name
            )

            livenessTask = streamOutput.startLivenessMonitor(
                deviceName: resolved.videoInput.name,
                staleAfterSeconds: 3,
                intervalSeconds: 0.25
            )

            recordingState.markReady()

            readiness?.ready()

            let startedAt = Date()
            let startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

            await stopSignal.wait()

            livenessTask?.cancel()
            livenessTask = nil

            session.stopRunning()

            runtimeObserver?.invalidate()
            runtimeObserver = nil

            let streamSnapshot = streamOutput.snapshot()

            if let failureDescription = streamSnapshot.writerFailureDescription {
                throw CaptureError.videoCapture(
                    "Camera \(resolved.videoInput.name) failed while recording. \(failureDescription)"
                )
            }

            guard streamSnapshot.sampleCount > 0 else {
                throw CaptureError.videoCapture(
                    "No camera output callbacks were received from \(resolved.videoInput.name). Dropped callbacks: \(streamSnapshot.droppedSampleCount)."
                )
            }

            guard streamSnapshot.writtenFrameCount > 0 else {
                throw CaptureError.videoCapture(
                    "No camera frames were written for \(resolved.videoInput.name). Sample callbacks: \(streamSnapshot.sampleCount). Dropped callbacks: \(streamSnapshot.droppedSampleCount)."
                )
            }

            let duration = Date().timeIntervalSince(
                startedAt
            )

            let finishResult = try await sink.finish()

            return CaptureCameraVideoRecordingResult(
                output: finishResult.output,
                camera: resolved.videoInput,
                durationSeconds: max(
                    0,
                    Int(
                        duration.rounded()
                    )
                ),
                frameCount: finishResult.frameCount,
                video: finishResult.video,
                startedAt: startedAt,
                startedHostTimeSeconds: startedHostTimeSeconds,
                firstSampleAt: finishResult.firstSampleAt,
                firstPresentationTimeSeconds: finishResult.firstPresentationTimeSeconds,
                segments: finishResult.segments
            )
        } catch {
            livenessTask?.cancel()
            runtimeObserver?.invalidate()

            if session.isRunning {
                session.stopRunning()
            }

            sink.cancel()

            if error is CancellationError {
                throw error
            }

            throw CameraVideoAttemptFailure(
                underlyingError: error,
                happenedAfterReadiness: recordingState.isReady
            )
        }
    }

    func stableStartupFrameCount(
        fps: Int
    ) -> Int {
        min(
            12,
            max(
                3,
                fps / 4
            )
        )
    }

    func validateOutput(
        _ output: URL
    ) throws {
        let ext = output.pathExtension.lowercased()

        guard ext == "mov" || ext == "mp4" else {
            throw CaptureError.videoCapture(
                "Camera video capture currently writes .mov or .mp4 output."
            )
        }
    }

    func ensureCameraPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(
            for: .video
        ) {
        case .authorized:
            return

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(
                for: .video
            )

            guard granted else {
                throw CaptureError.videoCapture(
                    "Camera permission was not granted."
                )
            }

        case .denied, .restricted:
            throw CaptureError.videoCapture(
                "Camera permission is not granted to this process. Grant it to the terminal host app, then fully quit and reopen that app."
            )

        @unknown default:
            throw CaptureError.videoCapture(
                "Camera permission is unavailable."
            )
        }
    }

    func cameraDevice(
        matching device: CaptureDevice
    ) throws -> AVCaptureDevice {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .continuityCamera,
                .external,
            ],
            mediaType: .video,
            position: .unspecified
        ).devices

        guard let camera = devices.first(
            where: {
                $0.uniqueID == device.id
                    || $0.localizedName == device.name
            }
        ) else {
            throw CaptureError.deviceNotFound(
                kind: .video_input,
                value: device.id
            )
        }

        return camera
    }

    func configure(
        session: AVCaptureSession,
        cameraDevice: AVCaptureDevice,
        videoOutput: AVCaptureVideoDataOutput,
        streamOutput: CameraVideoStreamOutput,
        fps: Int
    ) throws {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }

        guard session.canSetSessionPreset(
            .high
        ) else {
            throw CaptureError.videoCapture(
                "Could not configure camera session preset."
            )
        }

        session.sessionPreset = .high

        let input = try AVCaptureDeviceInput(
            device: cameraDevice
        )

        guard session.canAddInput(
            input
        ) else {
            throw CaptureError.videoCapture(
                "Could not add camera input \(cameraDevice.localizedName)."
            )
        }

        session.addInput(
            input
        )

        try validateRequestedFrameRate(
            cameraDevice,
            fps: fps
        )

        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]

        guard session.canAddOutput(
            videoOutput
        ) else {
            throw CaptureError.videoCapture(
                "Could not add camera video output."
            )
        }

        session.addOutput(
            videoOutput
        )

        videoOutput.setSampleBufferDelegate(
            streamOutput,
            queue: streamOutput.queue
        )
    }

    func validateRequestedFrameRate(
        _ device: AVCaptureDevice,
        fps: Int
    ) throws {
        guard fps > 0 else {
            throw CaptureError.invalidFrameRate(
                fps
            )
        }
    }

    func describe(
        _ camera: CaptureVideoInput
    ) -> String {
        switch camera {
        case .systemDefault:
            return "default camera"

        case .name(let name):
            return name

        case .identifier(let identifier):
            return identifier
        }
    }

    func describe(
        _ error: Error
    ) -> String {
        CaptureErrorDescription.technical(
            error
        )
    }
}
