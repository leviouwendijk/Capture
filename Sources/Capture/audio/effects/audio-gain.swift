import Foundation

public enum AudioGain {}

public struct AudioGainFactory: Sendable {
    public init() {}

    public func standard(
        _ amount: Float = 1
    ) -> AudioGain.Standard {
        AudioGain.Standard(
            amount
        )
    }
}

public extension AudioGain {
    struct Standard: AudioProcessor {
        public let amount: Float

        public init(
            _ amount: Float = 1
        ) {
            self.amount = amount
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            buffer.mapFloatSamples { sample in
                sample * amount
            }
        }
    }
}
