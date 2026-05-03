import Foundation

public extension Audio.Effects {
    struct Gate: Audio.Processor {
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
}

private extension Audio.Effects.Gate {
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
