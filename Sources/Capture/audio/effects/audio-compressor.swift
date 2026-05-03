import Foundation

public enum AudioCompressor {}

public struct AudioCompressorFactory: Sendable {
    public init() {}

    public func standard(
        threshold: Float = 0.18,
        ratio: Float = 3,
        makeup: Float = 1
    ) -> AudioCompressor.Standard {
        AudioCompressor.Standard(
            threshold: threshold,
            ratio: ratio,
            makeup: makeup
        )
    }

    public func softKnee(
        threshold: Float = 0.18,
        ratio: Float = 3,
        makeup: Float = 1,
        knee: Float = 0.08
    ) -> AudioCompressor.SoftKnee {
        AudioCompressor.SoftKnee(
            threshold: threshold,
            ratio: ratio,
            makeup: makeup,
            knee: knee
        )
    }

    public func vintage(
        threshold: Float = 0.12,
        ratio: Float = 2,
        makeup: Float = 1.2
    ) -> AudioCompressor.Vintage {
        AudioCompressor.Vintage(
            threshold: threshold,
            ratio: ratio,
            makeup: makeup
        )
    }
}

public extension AudioCompressor {
    struct Standard: AudioProcessor {
        public let threshold: Float
        public let ratio: Float
        public let makeup: Float

        public init(
            threshold: Float = 0.18,
            ratio: Float = 3,
            makeup: Float = 1
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

    struct SoftKnee: AudioProcessor {
        public let threshold: Float
        public let ratio: Float
        public let makeup: Float
        public let knee: Float

        public init(
            threshold: Float = 0.18,
            ratio: Float = 3,
            makeup: Float = 1,
            knee: Float = 0.08
        ) {
            self.threshold = threshold
            self.ratio = ratio
            self.makeup = makeup
            self.knee = knee
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

    struct Vintage: AudioProcessor {
        private var compressor: AudioCompressor.SoftKnee

        public init(
            threshold: Float = 0.12,
            ratio: Float = 2,
            makeup: Float = 1.2
        ) {
            self.compressor = AudioCompressor.SoftKnee(
                threshold: threshold,
                ratio: ratio,
                makeup: makeup,
                knee: 0.12
            )
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            try compressor.process(
                buffer
            )
        }
    }
}

private extension AudioCompressor.Standard {
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

private extension AudioCompressor.SoftKnee {
    func compress(
        _ sample: Float
    ) -> Float {
        let magnitude = abs(
            sample
        )

        guard threshold > 0,
              ratio > 1,
              knee > 0 else {
            return sample
        }

        let lower = threshold - knee / 2
        let upper = threshold + knee / 2

        if magnitude <= lower {
            return sample
        }

        let hard = hardCompress(
            sample
        )

        if magnitude >= upper {
            return hard
        }

        let blend = smooth(
            (magnitude - lower) / knee
        )

        return sample + (hard - sample) * blend
    }

    func hardCompress(
        _ sample: Float
    ) -> Float {
        let magnitude = abs(
            sample
        )

        guard magnitude > threshold else {
            return sample
        }

        let compressed = threshold
            + (magnitude - threshold) / ratio

        return sample < 0
            ? -compressed
            : compressed
    }

    func smooth(
        _ value: Float
    ) -> Float {
        let x = max(
            0,
            min(
                1,
                value
            )
        )

        return x * x * (3 - 2 * x)
    }
}
