import Foundation

public enum AudioLimiter {}

public struct AudioLimiterFactory: Sendable {
    public init() {}

    public func standard(
        ceiling: Float = 1
    ) -> AudioLimiter.Standard {
        AudioLimiter.Standard(
            ceiling: ceiling
        )
    }
}

public extension AudioLimiter {
    struct Standard: AudioProcessor {
        public let ceiling: Float

        public init(
            ceiling: Float = 1
        ) {
            self.ceiling = ceiling
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            let limit = abs(
                ceiling
            )

            return buffer.mapFloatSamples { sample in
                max(
                    -limit,
                    min(
                        limit,
                        sample
                    )
                )
            }
        }
    }
}
