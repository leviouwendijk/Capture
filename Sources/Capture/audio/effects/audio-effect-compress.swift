import Foundation

public extension Audio.Effects {
    struct Compress: Audio.Processor {
        public let threshold: Float
        public let ratio: Float
        public let makeup: Float

        public init(
            threshold: Float = 0.18,
            ratio: Float = 3.0,
            makeup: Float = 1.0
        ) {
            self.threshold = threshold
            self.ratio = ratio
            self.makeup = makeup
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            buffer.mapFloatSamples { sample in
                compress(
                    sample
                ) * makeup
            }
        }
    }
}

private extension Audio.Effects.Compress {
    func compress(
        _ sample: Float
    ) -> Float {
        let magnitude = abs(
            sample
        )

        guard threshold > 0,
              ratio > 1,
              magnitude > threshold else {
            return sample
        }

        let compressed = threshold
            + (magnitude - threshold) / ratio

        return sample < 0
            ? -compressed
            : compressed
    }
}
