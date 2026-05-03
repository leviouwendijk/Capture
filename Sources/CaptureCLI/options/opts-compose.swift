import Arguments
import Capture
import Foundation

struct ComposeCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let workspace: CaptureWorkspaceOptions
    let durationSeconds: Int?
    let microphoneChain: AudioChain
    let layoutDescription: String
    let configuration: CaptureCompositionConfiguration

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
        self.microphoneChain = arguments.microphoneChain.chain
        self.layoutDescription = try arguments.layout.description()
        self.configuration = try CaptureCompositionConfiguration(
            camera: arguments.camera.camera,
            video: video,
            audio: audio,
            systemAudio: systemAudio,
            audioMix: audioMix,
            layout: try arguments.layout.compositionLayout(),
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

        @Group("camera")
        var camera: CaptureCameraCLIOptions

        @Group("audio")
        var microphone: CaptureMicrophoneOptions

        @Group("mic-chain")
        var microphoneChain: CaptureMicrophoneChainOptions

        @Group("system-audio")
        var systemAudio: CaptureSystemAudioCLIOptions

        @Group("layout")
        var layout: CaptureCompositionLayoutCLIOptions

        init() {}
    }
}
