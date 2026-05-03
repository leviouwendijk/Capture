import Foundation

public extension Audio.Effects {
    struct Gain: Audio.Processor {
        public let amount: Float

        public init(
            _ amount: Float
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
