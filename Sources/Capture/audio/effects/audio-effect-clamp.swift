import Foundation

public extension Audio.Effects {
    struct Clamp: Audio.Processor {
        public init() {}

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            buffer.mapFloatSamples { sample in
                max(
                    -1,
                    min(
                        1,
                        sample
                    )
                )
            }
        }
    }
}
