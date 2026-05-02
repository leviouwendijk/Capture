import Arguments
import Capture
import Foundation

struct LiveAudioSmokeCommandOptions: Sendable, ArgumentParsed {
    typealias ArgumentPayload = Payload

    let smoke: CaptureLiveAudioSmokeOptions

    init(
        arguments: Payload
    ) throws {
        self.smoke = try CaptureLiveAudioSmokeOptions(
            audio: arguments.microphone.audio(
                sampleRate: arguments.sampleRate,
                channel: arguments.channel,
                codec: .pcm
            ),
            durationSeconds: arguments.durationSeconds
        )
    }

    struct Payload: ArgumentGroup {
        @Group("audio")
        var microphone: CaptureMicrophoneOptions

        @Opt(
            "duration",
            short: "d",
            default: 2
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
    }
}
