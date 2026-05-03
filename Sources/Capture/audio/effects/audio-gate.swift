import Foundation

public enum AudioGate {}

public struct AudioGateFactory: Sendable {
    public init() {}

    public func standard(
        floor: Float = 0.002,
        open: Float = 0.008
    ) -> AudioGate.Soft {
        soft(
            floor: floor,
            open: open
        )
    }

    public func soft(
        floor: Float = 0.002,
        open: Float = 0.008
    ) -> AudioGate.Soft {
        AudioGate.Soft(
            floor: floor,
            open: open
        )
    }

    public func hard(
        threshold: Float = 0.006
    ) -> AudioGate.Hard {
        AudioGate.Hard(
            threshold: threshold
        )
    }
}

public extension AudioGate {
    struct Soft: AudioProcessor {
        public let floor: Float
        public let open: Float

        public init(
            floor: Float = 0.002,
            open: Float = 0.008
        ) {
            self.floor = floor
            self.open = open
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            buffer.mapFloatSamples { sample in
                sample * gain(
                    magnitude: abs(
                        sample
                    )
                )
            }
        }
    }

    struct Hard: AudioProcessor {
        public let threshold: Float

        public init(
            threshold: Float = 0.006
        ) {
            self.threshold = threshold
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            buffer.mapFloatSamples { sample in
                abs(
                    sample
                ) >= threshold
                    ? sample
                    : 0
            }
        }
    }
}

private extension AudioGate.Soft {
    func gain(
        magnitude: Float
    ) -> Float {
        guard open > floor else {
            return magnitude >= floor ? 1 : 0
        }

        let x = clamp01(
            (magnitude - floor) / (open - floor)
        )

        return x * x * (3 - 2 * x)
    }

    func clamp01(
        _ value: Float
    ) -> Float {
        max(
            0,
            min(
                1,
                value
            )
        )
    }
}
