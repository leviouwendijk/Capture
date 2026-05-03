import Capture
import Foundation

enum CameraCommandRunner {
    static func run(
        _ options: CameraCommandOptions
    ) async throws {
        let provider = MacCaptureDeviceProvider()

        let resolvedVideo = try await CaptureCLI.resolvedCameraVideoPreview(
            configuration: options.configuration,
            provider: provider
        )

        try CaptureCLIStoragePreflight.ensureAvailable(
            output: options.output,
            workspace: options.workspace,
            video: resolvedVideo,
            durationSeconds: options.durationSeconds,
            mode: .camera
        )

        let timer = CaptureCLI.recordingTimer(
            limitSeconds: options.durationSeconds,
            output: options.output,
            audioName: audioName(
                options.configuration.audio
            ),
            systemAudioEnabled: false,
            audioMix: options.configuration.audioMix,
            video: resolvedVideo,
            cameraName: options.cameraName
        )

        let progressRenderer = CaptureCLIProgressRenderer(
            recordingTimer: timer,
            output: options.output
        )

        if let durationSeconds = options.durationSeconds {
            let session = CameraCaptureSession(
                configuration: options.configuration,
                options: try CaptureRecordOptions(
                    durationSeconds: durationSeconds
                ),
                workspace: options.workspace,
                deviceProvider: provider,
                microphoneChain: options.microphoneChain
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            await timer.start()

            do {
                let result = try await session.start()

                await progressRenderer.finishAfterSuccess()

                CaptureCLI.writeCameraSummary(
                    result: result,
                    exportDurationSeconds: await progressRenderer.exportDurationSeconds()
                )
            } catch {
                await progressRenderer.finishAfterError()
                throw error
            }
        } else {
            let stopSignal = CaptureStopSignal()
            let listener = CaptureCLIStopListener(
                stopSignal: stopSignal
            )

            let session = CameraCaptureSession(
                configuration: options.configuration,
                workspace: options.workspace,
                deviceProvider: provider,
                microphoneChain: options.microphoneChain
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            listener.start()
            await timer.start()

            do {
                let result = try await session.startUntilStopped(
                    stopSignal: stopSignal
                )

                listener.stop()

                await progressRenderer.finishAfterSuccess()

                CaptureCLI.writeCameraSummary(
                    result: result,
                    exportDurationSeconds: await progressRenderer.exportDurationSeconds()
                )
            } catch {
                listener.stop()
                await progressRenderer.finishAfterError()
                throw error
            }
        }
    }
}
