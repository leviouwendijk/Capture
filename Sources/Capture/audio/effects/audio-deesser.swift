import Darwin
import Foundation

public enum AudioDeEsser {}

public struct AudioDeEsserFactory: Sendable {
    public init() {}

    public func standard(
        frequency: Float = 6_500,
        q: Float = 2.5,
        thresholdDB: Float = -34,
        ratio: Float = 5,
        maxReductionDB: Float = 8,
        attackMS: Float = 1.5,
        releaseMS: Float = 70
    ) -> AudioDeEsser.Standard {
        AudioDeEsser.Standard(
            frequency: frequency,
            q: q,
            thresholdDB: thresholdDB,
            ratio: ratio,
            maxReductionDB: maxReductionDB,
            attackMS: attackMS,
            releaseMS: releaseMS
        )
    }

    public func vocal(
        frequency: Float = 6_500,
        thresholdDB: Float = -34,
        maxReductionDB: Float = 8
    ) -> AudioDeEsser.Standard {
        standard(
            frequency: frequency,
            q: 2.5,
            thresholdDB: thresholdDB,
            ratio: 5,
            maxReductionDB: maxReductionDB,
            attackMS: 1.5,
            releaseMS: 70
        )
    }
}

public extension AudioDeEsser {
    struct Standard: AudioProcessor {
        public let frequency: Float
        public let q: Float
        public let thresholdDB: Float
        public let ratio: Float
        public let maxReductionDB: Float
        public let attackMS: Float
        public let releaseMS: Float

        private var states: [AudioDeEsserChannelState] = []
        private var preparedSampleRate: Int?
        private var preparedChannelCount: Int?

        public init(
            frequency: Float = 6_500,
            q: Float = 2.5,
            thresholdDB: Float = -34,
            ratio: Float = 5,
            maxReductionDB: Float = 8,
            attackMS: Float = 1.5,
            releaseMS: Float = 70
        ) {
            self.frequency = frequency
            self.q = q
            self.thresholdDB = thresholdDB
            self.ratio = ratio
            self.maxReductionDB = maxReductionDB
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

            let configuration = AudioDeEsserConfiguration(
                thresholdDB: thresholdDB,
                ratio: ratio,
                maxReductionDB: maxReductionDB,
                attackMS: attackMS,
                releaseMS: releaseMS
            )

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
                    configuration: configuration,
                    sampleRate: sampleRate
                )
            }

            states = localStates

            return processed
        }
    }
}

private extension AudioDeEsser.Standard {
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
            AudioDeEsserChannelState(
                frequency: frequency,
                q: q,
                sampleRate: buffer.sampleRate
            )
        }

        preparedSampleRate = buffer.sampleRate
        preparedChannelCount = buffer.channelCount
    }
}

private struct AudioDeEsserConfiguration: Sendable {
    let thresholdDB: Float
    let ratio: Float
    let maxReductionDB: Float
    let attackMS: Float
    let releaseMS: Float
}

private struct AudioDeEsserChannelState: Sendable {
    private var detector: AudioDeEsserBiquad
    private var envelope: Float = 0
    private var gain: Float = 1

    init(
        frequency: Float,
        q: Float,
        sampleRate: Int
    ) {
        self.detector = AudioDeEsserBiquad.bandpass(
            frequency: frequency,
            q: q,
            sampleRate: sampleRate
        )
    }

    mutating func process(
        _ sample: Float,
        configuration: AudioDeEsserConfiguration,
        sampleRate: Int
    ) -> Float {
        let sibilance = detector.process(
            sample
        )
        let magnitude = abs(
            sibilance
        )
        let envelopeCoefficient = AudioDeEsserMath.smoothingCoefficient(
            milliseconds: magnitude > envelope
                ? configuration.attackMS
                : configuration.releaseMS,
            sampleRate: sampleRate
        )

        envelope = envelopeCoefficient * envelope
            + (1 - envelopeCoefficient) * magnitude

        let levelDB = AudioDeEsserMath.linearToDB(
            envelope
        )
        let reductionDB = AudioDeEsserMath.gainReductionDB(
            levelDB: levelDB,
            thresholdDB: configuration.thresholdDB,
            ratio: configuration.ratio,
            maxReductionDB: configuration.maxReductionDB
        )
        let targetGain = AudioDeEsserMath.dbToLinear(
            reductionDB
        )
        let gainCoefficient = AudioDeEsserMath.smoothingCoefficient(
            milliseconds: targetGain < gain
                ? configuration.attackMS
                : configuration.releaseMS,
            sampleRate: sampleRate
        )

        gain = gainCoefficient * gain
            + (1 - gainCoefficient) * targetGain

        return sample * gain
    }
}

private struct AudioDeEsserBiquad: Sendable {
    let b0: Float
    let b1: Float
    let b2: Float
    let a1: Float
    let a2: Float

    var z1: Float = 0
    var z2: Float = 0

    mutating func process(
        _ input: Float
    ) -> Float {
        let output = b0 * input + z1

        z1 = b1 * input - a1 * output + z2
        z2 = b2 * input - a2 * output

        return output
    }

    static func bandpass(
        frequency: Float,
        q: Float,
        sampleRate: Int
    ) -> AudioDeEsserBiquad {
        guard let values = AudioDeEsserBiquadValues(
            frequency: frequency,
            q: q,
            sampleRate: sampleRate
        ) else {
            return bypass()
        }

        let b0 = values.alpha
        let b1: Float = 0
        let b2 = -values.alpha
        let a0 = 1 + values.alpha
        let a1 = -2 * values.cosine
        let a2 = 1 - values.alpha

        return normalized(
            b0: b0,
            b1: b1,
            b2: b2,
            a0: a0,
            a1: a1,
            a2: a2
        )
    }

    static func normalized(
        b0: Float,
        b1: Float,
        b2: Float,
        a0: Float,
        a1: Float,
        a2: Float
    ) -> AudioDeEsserBiquad {
        guard a0 != 0,
              a0.isFinite else {
            return bypass()
        }

        return AudioDeEsserBiquad(
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0
        )
    }

    static func bypass() -> AudioDeEsserBiquad {
        AudioDeEsserBiquad(
            b0: 1,
            b1: 0,
            b2: 0,
            a1: 0,
            a2: 0
        )
    }
}

private struct AudioDeEsserBiquadValues {
    let frequency: Float
    let q: Float
    let sampleRate: Int
    let omega: Float
    let sine: Float
    let cosine: Float
    let alpha: Float

    init?(
        frequency: Float,
        q: Float,
        sampleRate: Int
    ) {
        guard sampleRate > 0,
              frequency > 0,
              q > 0 else {
            return nil
        }

        let nyquist = Float(
            sampleRate
        ) / 2
        let safeFrequency = max(
            10,
            min(
                frequency,
                nyquist - 10
            )
        )

        guard safeFrequency.isFinite,
              safeFrequency > 0,
              safeFrequency < nyquist else {
            return nil
        }

        let omega = 2 * Float.pi * safeFrequency / Float(
            sampleRate
        )
        let sine = sinf(
            omega
        )
        let cosine = cosf(
            omega
        )

        self.frequency = safeFrequency
        self.q = q
        self.sampleRate = sampleRate
        self.omega = omega
        self.sine = sine
        self.cosine = cosine
        self.alpha = sine / (2 * q)
    }
}

private enum AudioDeEsserMath {
    static func dbToLinear(
        _ db: Float
    ) -> Float {
        powf(
            10,
            db / 20
        )
    }

    static func linearToDB(
        _ value: Float
    ) -> Float {
        20 * log10f(
            max(
                abs(
                    value
                ),
                0.000_000_1
            )
        )
    }

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

    static func gainReductionDB(
        levelDB: Float,
        thresholdDB: Float,
        ratio: Float,
        maxReductionDB: Float
    ) -> Float {
        let safeRatio = max(
            1,
            ratio
        )

        guard safeRatio > 1 else {
            return 0
        }

        let over = levelDB - thresholdDB

        guard over > 0 else {
            return 0
        }

        let reduction = over * (
            1 - 1 / safeRatio
        )

        return -min(
            max(
                0,
                maxReductionDB
            ),
            reduction
        )
    }
}
