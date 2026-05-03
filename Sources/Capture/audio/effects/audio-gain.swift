import Darwin
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

    public func db(
        _ db: Float = 0
    ) -> AudioGain.Standard {
        AudioGain.Standard(
            Self.dbToLinear(
                db
            )
        )
    }
}

private extension AudioGainFactory {
    static func dbToLinear(
        _ db: Float
    ) -> Float {
        powf(
            10,
            db / 20
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
