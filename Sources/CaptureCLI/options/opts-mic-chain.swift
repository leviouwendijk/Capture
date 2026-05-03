import Arguments
import Capture
import Foundation

struct CaptureMicrophoneChainOptions: Sendable, ArgumentGroup {
    @Opt(
        "mic-chain",
        default: .none
    )
    var preset: AudioChainPreset

    var chain: AudioChain {
        preset.chain
    }

    init() {}
}
