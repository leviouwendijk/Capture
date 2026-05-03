import Arguments
import Capture
import Foundation

struct AudioCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let output: URL
    let audio: CaptureAudioOptions
    let microphoneChain: AudioChain
    let durationSeconds: Int?

    init(
        arguments: Payload
    ) throws {
        self.output = try arguments.output.url()
        self.audio = try arguments.microphone.audio(
            sampleRate: arguments.sampleRate,
            channel: arguments.channel,
            codec: .pcm
        )
        self.microphoneChain = arguments.microphoneChain.chain
        self.durationSeconds = try arguments.duration.optional()
    }

    struct Payload: ArgumentGroup {
        @Group("output")
        var output: CaptureOutputOptions

        @Group("duration")
        var duration: CaptureDurationOptions

        @Group("audio")
        var microphone: CaptureMicrophoneOptions

        @Group("mic-chain")
        var microphoneChain: CaptureMicrophoneChainOptions

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
