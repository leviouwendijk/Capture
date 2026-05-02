import Capture
import Foundation

enum ComposeCommandRunner {
    static func run(
        _ options: ComposeCommandOptions
    ) async throws {
        let provider = MacCaptureDeviceProvider()

        let previewConfiguration = try CaptureConfiguration(
            display: options.configuration.display,
            video: options.configuration.video,
            audio: options.configuration.audio,
            systemAudio: options.configuration.systemAudio,
            audioMix: options.configuration.audioMix,
            container: options.configuration.container,
            output: options.output
        )

        let resolvedVideo = try await CaptureCLI.resolvedVideoPreview(
            configuration: previewConfiguration,
            provider: provider
        )

        try CaptureCLIStoragePreflight.ensureAvailable(
            output: options.output,
            workspace: options.workspace,
            video: resolvedVideo,
            durationSeconds: options.durationSeconds,
            mode: .composition
        )

        let timer = CaptureCLI.recordingTimer(
            limitSeconds: options.durationSeconds,
            output: options.output,
            audioName: audioName(
                options.configuration.audio
            ),
            systemAudioEnabled: options.configuration.systemAudio.enabled,
            audioMix: options.configuration.audioMix,
            video: resolvedVideo,
            cameraName: cameraName(
                options.configuration.camera
            ),
            layoutDescription: options.layoutDescription
        )

        let progressRenderer = CaptureCLIProgressRenderer(
            recordingTimer: timer,
            output: options.output
        )

        if let durationSeconds = options.durationSeconds {
            let session = CaptureCompositionSession(
                configuration: options.configuration,
                options: try CaptureRecordOptions(
                    durationSeconds: durationSeconds
                ),
                workspace: options.workspace,
                deviceProvider: provider
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            await timer.start()

            do {
                let result = try await session.start()

                await progressRenderer.finishAfterSuccess()

                CaptureCLI.writeCompositionSummary(
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

            let session = CaptureCompositionSession(
                configuration: options.configuration,
                workspace: options.workspace,
                deviceProvider: provider
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

                CaptureCLI.writeCompositionSummary(
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

