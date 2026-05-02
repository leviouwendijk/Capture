import Arguments
import Capture
import Foundation

struct AudioCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let audio: CaptureAudioOptions
    let durationSeconds: Int

    init(
        arguments: Payload
    ) throws {
        self.output = try arguments.output.url()
        self.audio = try arguments.microphone.audio(
            sampleRate: arguments.sampleRate,
            channel: arguments.channel,
            codec: .pcm
        )
        self.durationSeconds = try CaptureAudioRecordOptions(
            durationSeconds: arguments.durationSeconds
        ).durationSeconds
    }

    struct Payload: ArgumentGroup {
        @Group("output")
        var output: CaptureOutputOptions

        @Group("audio")
        var microphone: CaptureMicrophoneOptions

        @Opt(
            "duration",
            short: "d",
            default: 5
        )
        var durationSeconds: Int

        @Opt(
            "sample-rate",
            default: 48_000
        )
        var sampleRate: Int

        @Opt(
            "channel",
            default: 1
        )
        var channel: Int

        init() {}
    }
}

struct VideoCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let video: CaptureVideoOptions
    let container: CaptureContainer
    let durationSeconds: Int
    let configuration: CaptureConfiguration

    init(
        arguments: Payload
    ) throws {
        let output = try arguments.output.url()
        let video = try arguments.video.video(
            defaultFPS: 24
        )

        self.output = output
        self.video = video
        self.container = try CaptureCLI.container(
            for: output
        )
        self.durationSeconds = try arguments.duration.fixed(
            default: 5
        )
        self.configuration = try CaptureConfiguration(
            video: video,
            audio: CaptureAudioOptions(),
            container: try CaptureCLI.container(
                for: output
            ),
            output: output
        )
    }

    struct Payload: ArgumentGroup {
        @Group("output")
        var output: CaptureOutputOptions

        @Group("duration")
        var duration: CaptureDurationOptions

        @Group("video")
        var video: CaptureVideoCLIOptions

        init() {}
    }
}

struct CameraCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let workspace: CaptureWorkspaceOptions
    let durationSeconds: Int?
    let video: CaptureVideoOptions
    let audio: CaptureAudioOptions
    let audioMix: CaptureAudioMixOptions
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

        @Group("gain")
        var gain: CaptureMicrophoneGainOptions

        init() {}
    }
}

struct ComposeCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let workspace: CaptureWorkspaceOptions
    let durationSeconds: Int?
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

        @Group("system-audio")
        var systemAudio: CaptureSystemAudioCLIOptions

        @Group("layout")
        var layout: CaptureCompositionLayoutCLIOptions

        init() {}
    }
}

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
