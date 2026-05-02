import Arguments
import Capture
import Foundation

struct RecordCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let workspace: CaptureWorkspaceOptions
    let durationSeconds: Int?
    let configuration: CaptureConfiguration

    init(
        arguments: Payload
    ) throws {
        let output = try arguments.output.url()
        let video = try arguments.video.video(
            defaultFPS: 24
        )
        let audio = try arguments.microphone.audio()
        let systemAudio = try arguments.systemAudio.systemAudio()
        let audioMix = try arguments.systemAudio.audioMix()

        self.output = output
        self.workspace = arguments.workspace.workspace()
        self.durationSeconds = try arguments.duration.optional()
        self.configuration = try CaptureConfiguration(
            video: video,
            audio: audio,
            systemAudio: systemAudio,
            audioMix: audioMix,
            container: try CaptureCLI.container(
                for: output
            ),
            output: output
        )
    }

    struct Payload: ArgumentGroup {
        @Group("output")
        var output: CaptureOutputOptions

        @Group("workspace")
        var workspace: CaptureWorkspaceCLIOptions

        @Group("duration")
        var duration: CaptureDurationOptions

        @Group("video")
        var video: CaptureVideoCLIOptions

        @Group("audio")
        var microphone: CaptureMicrophoneOptions

        @Group("system-audio")
        var systemAudio: CaptureSystemAudioCLIOptions

        init() {}
    }
}
