import Darwin
import Foundation

public enum AudioLimiter {}

public struct AudioLimiterFactory: Sendable {
    public init() {}

    public func standard(
        ceiling: Float = 0.89,
        knee: Float = 0.08
    ) -> AudioLimiter.Standard {
        AudioLimiter.Standard(
            ceiling: ceiling,
            knee: knee
        )
    }

    public func db(
        ceilingDB: Float = -3,
        kneeDB: Float = 2
    ) -> AudioLimiter.Standard {
        let ceiling = Self.dbToLinear(
            ceilingDB
        )

        let kneeWidth = max(
            0,
            ceiling - Self.dbToLinear(
                ceilingDB - abs(
                    kneeDB
                )
            )
        )

        return standard(
            ceiling: ceiling,
            knee: kneeWidth
        )
    }
}

private extension AudioLimiterFactory {
    static func dbToLinear(
        _ db: Float
    ) -> Float {
        powf(
            10,
            db / 20
        )
    }
}

public extension AudioLimiter {
    struct Standard: AudioProcessor {
        public let ceiling: Float
        public let knee: Float

        public init(
            ceiling: Float = 0.89,
            knee: Float = 0.08
        ) {
            self.ceiling = ceiling
            self.knee = knee
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            let resolvedCeiling = max(
                0.0001,
                min(
                    1,
                    abs(
                        ceiling
                    )
                )
            )
            let resolvedKnee = max(
                0,
                min(
                    resolvedCeiling,
                    abs(
                        knee
                    )
                )
            )
            let threshold = max(
                0,
                resolvedCeiling - resolvedKnee
            )

            return buffer.mapFloatSamples { sample in
                limit(
                    sample,
                    threshold: threshold,
                    ceiling: resolvedCeiling,
                    knee: resolvedKnee
                )
            }
        }
    }
}

private extension AudioLimiter.Standard {
    func limit(
        _ sample: Float,
        threshold: Float,
        ceiling: Float,
        knee: Float
    ) -> Float {
        let sign: Float = sample < 0 ? -1 : 1
        let magnitude = abs(
            sample
        )

        guard magnitude > threshold else {
            return sample
        }

        guard knee > 0 else {
            return sign * min(
                magnitude,
                ceiling
            )
        }

        let excess = magnitude - threshold
        let shaped = threshold + knee * tanhf(
            excess / knee
        )

        return sign * min(
            shaped,
            ceiling
        )
    }
}
