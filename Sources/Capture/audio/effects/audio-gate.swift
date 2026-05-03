import Darwin
import Foundation

public enum AudioGate {}

public struct AudioGateFactory: Sendable {
    public init() {}

    public func standard(
        floor: Float = 0.002,
        open: Float = 0.008,
        attackMS: Float = 2,
        releaseMS: Float = 80
    ) -> AudioGate.Soft {
        soft(
            floor: floor,
            open: open,
            attackMS: attackMS,
            releaseMS: releaseMS
        )
    }

    public func soft(
        floor: Float = 0.002,
        open: Float = 0.008,
        attackMS: Float = 2,
        releaseMS: Float = 80
    ) -> AudioGate.Soft {
        AudioGate.Soft(
            floor: floor,
            open: open,
            attackMS: attackMS,
            releaseMS: releaseMS
        )
    }

    public func softDB(
        floorDB: Float = -64,
        openDB: Float = -42,
        attackMS: Float = 2,
        releaseMS: Float = 80
    ) -> AudioGate.Soft {
        soft(
            floor: Self.dbToLinear(
                floorDB
            ),
            open: Self.dbToLinear(
                openDB
            ),
            attackMS: attackMS,
            releaseMS: releaseMS
        )
    }

    public func hard(
        threshold: Float = 0.006
    ) -> AudioGate.Hard {
        AudioGate.Hard(
            threshold: threshold
        )
    }

    public func hardDB(
        thresholdDB: Float = -44
    ) -> AudioGate.Hard {
        hard(
            threshold: Self.dbToLinear(
                thresholdDB
            )
        )
    }
}

private extension AudioGateFactory {
    static func dbToLinear(
        _ db: Float
    ) -> Float {
        powf(
            10,
            db / 20
        )
    }
}

public extension AudioGate {
    struct Soft: AudioProcessor {
        public let floor: Float
        public let open: Float
        public let attackMS: Float
        public let releaseMS: Float

        private var states: [AudioGateSoftChannelState] = []
        private var preparedSampleRate: Int?
        private var preparedChannelCount: Int?

        public init(
            floor: Float = 0.002,
            open: Float = 0.008,
            attackMS: Float = 2,
            releaseMS: Float = 80
        ) {
            self.floor = floor
            self.open = open
            self.attackMS = attackMS
            self.releaseMS = releaseMS
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            prepare(
                buffer: buffer
            )

            guard !states.isEmpty else {
                return buffer
            }

            var localStates = states
            let sampleRate = buffer.sampleRate

            let processed = buffer.mapFloatSamplesWithChannel { sample, channel in
                let resolvedChannel = min(
                    max(
                        0,
                        channel
                    ),
                    localStates.count - 1
                )

                return localStates[resolvedChannel].process(
                    sample,
                    gate: self,
                    sampleRate: sampleRate
                )
            }

            states = localStates

            return processed
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
    mutating func prepare(
        buffer: CaptureAudioInputBuffer
    ) {
        let channelCount = max(
            1,
            buffer.channelCount
        )

        guard preparedSampleRate != buffer.sampleRate
                || preparedChannelCount != buffer.channelCount
                || states.count != channelCount else {
            return
        }

        states = (0..<channelCount).map { _ in
            AudioGateSoftChannelState()
        }

        preparedSampleRate = buffer.sampleRate
        preparedChannelCount = buffer.channelCount
    }

    func targetGain(
        magnitude: Float
    ) -> Float {
        let resolvedFloor = max(
            0,
            floor
        )
        let resolvedOpen = max(
            resolvedFloor + 0.000_001,
            open
        )
        let x = clamp01(
            (magnitude - resolvedFloor) / (resolvedOpen - resolvedFloor)
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

private struct AudioGateSoftChannelState: Sendable {
    private var envelope: Float = 0
    private var gain: Float = 0

    mutating func process(
        _ sample: Float,
        gate: AudioGate.Soft,
        sampleRate: Int
    ) -> Float {
        let magnitude = abs(
            sample
        )
        let envelopeCoefficient = AudioGateMath.smoothingCoefficient(
            milliseconds: magnitude > envelope
                ? gate.attackMS
                : gate.releaseMS,
            sampleRate: sampleRate
        )

        envelope = envelopeCoefficient * envelope
            + (1 - envelopeCoefficient) * magnitude

        let targetGain = gate.targetGain(
            magnitude: envelope
        )
        let gainCoefficient = AudioGateMath.smoothingCoefficient(
            milliseconds: targetGain > gain
                ? gate.attackMS
                : gate.releaseMS,
            sampleRate: sampleRate
        )

        gain = gainCoefficient * gain
            + (1 - gainCoefficient) * targetGain

        return sample * gain
    }
}

private enum AudioGateMath {
    static func smoothingCoefficient(
        milliseconds: Float,
        sampleRate: Int
    ) -> Float {
        guard sampleRate > 0 else {
            return 0
        }

        let seconds = max(
            0.1,
            milliseconds
        ) / 1_000

        return expf(
            -1 / (
                seconds * Float(
                    sampleRate
                )
            )
        )
    }
}
