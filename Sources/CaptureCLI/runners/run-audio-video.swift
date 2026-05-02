import Capture
import Foundation
import Terminal

enum AudioCommandRunner {
    static func run(
        _ options: AudioCommandOptions
    ) async throws {
        let configuration = try CaptureConfiguration(
            video: CaptureVideoOptions(),
            audio: options.audio,
            output: options.output
        )

        let mode = try CaptureRecordMode(
            durationSeconds: options.durationSeconds
        )

        let stopSignal = CaptureStopSignal()
        let listener: CaptureCLIStopListener?

        switch mode {
        case .live:
            listener = CaptureCLIStopListener(
                stopSignal: stopSignal
            )

            listener?.start()

        case .duration:
            listener = nil
        }

        let timer = CaptureCLI.recordingTimer(
            limitSeconds: mode.durationSeconds,
            output: options.output,
            audioName: audioName(
                options.audio
            ),
            audioSampleRate: options.audio.sampleRate,
            audioChannelCount: options.audio.channel,
            title: "capture: recording audio"
        )

        await timer.start()

        do {
            let result = try await CoreAudioRecorder().record.mode(
                mode,
                configuration: configuration,
                stopSignal: stopSignal
            )

            listener?.stop()

            await timer.stop(
                finalLine: "recording: stopped at \(TerminalDurationFormatter.format(TimeInterval(result.durationSeconds)))"
            )

            CaptureCLI.writeAudioSummary(
                result: result,
                audio: options.audio
            )
        } catch {
            listener?.stop()

            await timer.stop(
                finalLine: "recording: failed"
            )

            throw error
        }
    }
}

enum VideoCommandRunner {
    static func run(
        _ options: VideoCommandOptions
    ) async throws {
        let provider = MacCaptureDeviceProvider()

        let mode = try CaptureRecordMode(
            durationSeconds: options.durationSeconds
        )

        let resolvedVideo = try await CaptureCLI.resolvedVideoPreview(
            configuration: options.configuration,
            provider: provider
        )

        let stopSignal = CaptureStopSignal()
        let listener: CaptureCLIStopListener?

        switch mode {
        case .live:
            listener = CaptureCLIStopListener(
                stopSignal: stopSignal
            )

            listener?.start()

        case .duration:
            listener = nil
        }

        let timer = CaptureCLI.recordingTimer(
            limitSeconds: mode.durationSeconds,
            output: options.output,
            audioName: nil,
            video: resolvedVideo,
            title: "capture: recording video"
        )

        await timer.start()

        do {
            let result = try await ScreenCaptureVideoRecorder().record.mode(
                mode,
                configuration: options.configuration,
                stopSignal: stopSignal,
                deviceProvider: provider
            )

            listener?.stop()

            await timer.stop(
                finalLine: "recording: stopped at \(TerminalDurationFormatter.format(result.diagnostics.recordedSeconds))"
            )

            CaptureCLI.writeVideoSummary(
                result: result,
                exportDurationSeconds: nil
            )
        } catch {
            listener?.stop()

            await timer.stop(
                finalLine: "recording: failed"
            )

            throw error
        }
    }
}
