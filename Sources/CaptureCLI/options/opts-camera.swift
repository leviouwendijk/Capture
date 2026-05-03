import Arguments
import Capture
import Foundation

struct CameraCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let workspace: CaptureWorkspaceOptions
    let durationSeconds: Int?
    let video: CaptureVideoOptions
    let audio: CaptureAudioOptions
    let audioMix: CaptureAudioMixOptions
    let microphoneChain: AudioChain
    let cameraName: String
    let configuration: CaptureCameraConfiguration

    init(
        arguments: Payload
    ) throws {
        let output = try arguments.output.url()
        let video = try arguments.video.video(
            defaultFPS: 30,
            defaultCursor: false
        )
        let audio = try arguments.microphone.audio()
        let audioMix = try arguments.gain.audioMix()

        self.output = output
        self.workspace = arguments.workspace.workspace()
        self.durationSeconds = try arguments.duration.optional()
        self.video = video
        self.audio = audio
        self.audioMix = audioMix
        self.microphoneChain = arguments.microphoneChain.chain
        self.cameraName = arguments.camera.displayName
        self.configuration = try CaptureCameraConfiguration(
            camera: arguments.camera.camera,
            video: video,
            audio: audio,
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

        @Group("camera")
        var camera: CaptureCameraCLIOptions

        @Group("audio")
        var microphone: CaptureMicrophoneOptions

        @Group("mic-chain")
        var microphoneChain: CaptureMicrophoneChainOptions

        @Group("gain")
        var gain: CaptureMicrophoneGainOptions

        init() {}
    }
}
