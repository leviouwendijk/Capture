import Capture
import Foundation

enum AudioCommandRunner {
    static func run(
        _ options: AudioCommandOptions
    ) async throws {
        let configuration = try CaptureConfiguration(
            video: CaptureVideoOptions(),
            audio: options.audio,
            output: options.output
        )

        let result = try await CoreAudioRecorder().recordAudio(
            configuration: configuration,
            options: try CaptureAudioRecordOptions(
                durationSeconds: options.durationSeconds
            )
        )

        fputs(
            "capture: wrote audio \(result.output.path)\n",
            stderr
        )
    }
}

enum VideoCommandRunner {
    static func run(
        _ options: VideoCommandOptions
    ) async throws {
        let provider = MacCaptureDeviceProvider()

        let result = try await ScreenCaptureVideoRecorder().recordVideo(
            configuration: options.configuration,
            options: try CaptureVideoRecordOptions(
                durationSeconds: options.durationSeconds
            ),
            deviceProvider: provider
        )

        CaptureCLI.writeVideoSummary(
            result: result,
            exportDurationSeconds: nil
        )
    }
}
