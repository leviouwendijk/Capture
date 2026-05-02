import Arguments
import Capture
import Foundation

struct VideoCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let video: CaptureVideoOptions
    let container: CaptureContainer
    let durationSeconds: Int?
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
        self.durationSeconds = try arguments.duration.optional()
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
