import Darwin
import Foundation

public enum AudioEqualizer {}

public struct AudioEqualizerFactory: Sendable {
    public init() {}

    public func parametric(
        bands: [AudioEqualizer.Band] = []
    ) -> AudioEqualizer.Parametric {
        AudioEqualizer.Parametric(
            bands: bands
        )
    }

    public func neve1073(
        low: Float = 0,
        mid: Float = 0,
        high: Float = 0
    ) -> AudioEqualizer.Parametric {
        AudioEqualizer.Parametric(
            bands: [
                .lowshelf(
                    frequency: 110,
                    gain: low,
                    q: 0.707
                ),
                .bell(
                    frequency: 3_600,
                    gain: mid,
                    q: 1
                ),
                .highshelf(
                    frequency: 12_000,
                    gain: high,
                    q: 0.707
                ),
            ]
        )
    }
}

public extension AudioEqualizer {
    struct Band: Sendable, Hashable {
        public enum Kind: Sendable, Hashable {
            case bell
            case shelf(Shelf)
            case pass(Pass)

            public enum Shelf: Sendable, Hashable {
                case low
                case high
            }

            public enum Pass: Sendable, Hashable {
                case low
                case high
                case band
            }
        }

        public let kind: Kind
        public let frequency: Float
        public let gain: Float
        public let q: Float

        public init(
            kind: Kind,
            frequency: Float,
            gain: Float = 0,
            q: Float = 1
        ) {
            self.kind = kind
            self.frequency = frequency
            self.gain = gain
            self.q = q
        }

        public static func bell(
            frequency: Float,
            gain: Float,
            q: Float = 1
        ) -> AudioEqualizer.Band {
            AudioEqualizer.Band(
                kind: .bell,
                frequency: frequency,
                gain: gain,
                q: q
            )
        }

        public static func shelf(
            _ shelf: Kind.Shelf,
            frequency: Float,
            gain: Float,
            q: Float = 0.707
        ) -> AudioEqualizer.Band {
            AudioEqualizer.Band(
                kind: .shelf(
                    shelf
                ),
                frequency: frequency,
                gain: gain,
                q: q
            )
        }

        public static func lowshelf(
            frequency: Float,
            gain: Float,
            q: Float = 0.707
        ) -> AudioEqualizer.Band {
            shelf(
                .low,
                frequency: frequency,
                gain: gain,
                q: q
            )
        }

        public static func highshelf(
            frequency: Float,
            gain: Float,
            q: Float = 0.707
        ) -> AudioEqualizer.Band {
            shelf(
                .high,
                frequency: frequency,
                gain: gain,
                q: q
            )
        }

        public static func pass(
            _ pass: Kind.Pass,
            frequency: Float,
            q: Float = 0.707
        ) -> AudioEqualizer.Band {
            AudioEqualizer.Band(
                kind: .pass(
                    pass
                ),
                frequency: frequency,
                gain: 0,
                q: q
            )
        }

        public static func lowpass(
            frequency: Float,
            q: Float = 0.707
        ) -> AudioEqualizer.Band {
            pass(
                .low,
                frequency: frequency,
                q: q
            )
        }

        public static func highpass(
            frequency: Float,
            q: Float = 0.707
        ) -> AudioEqualizer.Band {
            pass(
                .high,
                frequency: frequency,
                q: q
            )
        }

        public static func bandpass(
            frequency: Float,
            q: Float = 1
        ) -> AudioEqualizer.Band {
            pass(
                .band,
                frequency: frequency,
                q: q
            )
        }

        public static func lowcut(
            frequency: Float,
            q: Float = 0.707
        ) -> AudioEqualizer.Band {
            highpass(
                frequency: frequency,
                q: q
            )
        }

        public static func highcut(
            frequency: Float,
            q: Float = 0.707
        ) -> AudioEqualizer.Band {
            lowpass(
                frequency: frequency,
                q: q
            )
        }
    }

    struct Parametric: AudioProcessor {
        public let bands: [AudioEqualizer.Band]

        private var filters: [[Biquad]] = []
        private var preparedSampleRate: Int?
        private var preparedChannelCount: Int?

        public init(
            bands: [AudioEqualizer.Band] = []
        ) {
            self.bands = bands
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            guard !bands.isEmpty else {
                return buffer
            }

            prepare(
                buffer: buffer
            )

            var localFilters = filters

            let processed = buffer.mapFloatSamplesWithChannel { sample, channel in
                var output = sample

                for bandIndex in localFilters.indices {
                    output = localFilters[bandIndex][channel].process(
                        output
                    )
                }

                return output
            }

            filters = localFilters

            return processed
        }
    }
}

private extension AudioEqualizer.Parametric {
    mutating func prepare(
        buffer: CaptureAudioInputBuffer
    ) {
        guard preparedSampleRate != buffer.sampleRate
                || preparedChannelCount != buffer.channelCount
                || filters.count != bands.count else {
            return
        }

        let channelCount = max(
            1,
            buffer.channelCount
        )

        filters = bands.map { band in
            (0..<channelCount).map { _ in
                Biquad.make(
                    band: band,
                    sampleRate: buffer.sampleRate
                )
            }
        }

        preparedSampleRate = buffer.sampleRate
        preparedChannelCount = buffer.channelCount
    }
}

private struct Biquad: Sendable {
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

    static func make(
        band: AudioEqualizer.Band,
        sampleRate: Int
    ) -> Biquad {
        switch band.kind {
        case .bell:
            return bell(
                frequency: band.frequency,
                gain: band.gain,
                q: band.q,
                sampleRate: sampleRate
            )

        case .shelf(.low):
            return lowshelf(
                frequency: band.frequency,
                gain: band.gain,
                q: band.q,
                sampleRate: sampleRate
            )

        case .shelf(.high):
            return highshelf(
                frequency: band.frequency,
                gain: band.gain,
                q: band.q,
                sampleRate: sampleRate
            )

        case .pass(.low):
            return lowpass(
                frequency: band.frequency,
                q: band.q,
                sampleRate: sampleRate
            )

        case .pass(.high):
            return highpass(
                frequency: band.frequency,
                q: band.q,
                sampleRate: sampleRate
            )

        case .pass(.band):
            return bandpass(
                frequency: band.frequency,
                q: band.q,
                sampleRate: sampleRate
            )
        }
    }

    static func bell(
        frequency: Float,
        gain: Float,
        q: Float,
        sampleRate: Int
    ) -> Biquad {
        guard let values = Values(
            frequency: frequency,
            q: q,
            sampleRate: sampleRate
        ) else {
            return bypass()
        }

        let amplitude = Float(
            pow(
                10.0,
                Double(
                    gain / 40
                )
            )
        )

        let b0 = 1 + values.alpha * amplitude
        let b1 = -2 * values.cosine
        let b2 = 1 - values.alpha * amplitude
        let a0 = 1 + values.alpha / amplitude
        let a1 = -2 * values.cosine
        let a2 = 1 - values.alpha / amplitude

        return normalized(
            b0: b0,
            b1: b1,
            b2: b2,
            a0: a0,
            a1: a1,
            a2: a2
        )
    }

    static func lowshelf(
        frequency: Float,
        gain: Float,
        q: Float,
        sampleRate: Int
    ) -> Biquad {
        guard let values = Values(
            frequency: frequency,
            q: q,
            sampleRate: sampleRate
        ) else {
            return bypass()
        }

        let amplitude = Float(
            pow(
                10.0,
                Double(
                    gain / 40
                )
            )
        )
        let root = sqrtf(
            amplitude
        )
        let twoRootAlpha = 2 * root * values.alpha

        let b0 = amplitude * (
            (amplitude + 1)
                - (amplitude - 1) * values.cosine
                + twoRootAlpha
        )
        let b1 = 2 * amplitude * (
            (amplitude - 1)
                - (amplitude + 1) * values.cosine
        )
        let b2 = amplitude * (
            (amplitude + 1)
                - (amplitude - 1) * values.cosine
                - twoRootAlpha
        )
        let a0 = (amplitude + 1)
            + (amplitude - 1) * values.cosine
            + twoRootAlpha
        let a1 = -2 * (
            (amplitude - 1)
                + (amplitude + 1) * values.cosine
        )
        let a2 = (amplitude + 1)
            + (amplitude - 1) * values.cosine
            - twoRootAlpha

        return normalized(
            b0: b0,
            b1: b1,
            b2: b2,
            a0: a0,
            a1: a1,
            a2: a2
        )
    }

    static func highshelf(
        frequency: Float,
        gain: Float,
        q: Float,
        sampleRate: Int
    ) -> Biquad {
        guard let values = Values(
            frequency: frequency,
            q: q,
            sampleRate: sampleRate
        ) else {
            return bypass()
        }

        let amplitude = Float(
            pow(
                10.0,
                Double(
                    gain / 40
                )
            )
        )
        let root = sqrtf(
            amplitude
        )
        let twoRootAlpha = 2 * root * values.alpha

        let b0 = amplitude * (
            (amplitude + 1)
                + (amplitude - 1) * values.cosine
                + twoRootAlpha
        )
        let b1 = -2 * amplitude * (
            (amplitude - 1)
                + (amplitude + 1) * values.cosine
        )
        let b2 = amplitude * (
            (amplitude + 1)
                + (amplitude - 1) * values.cosine
                - twoRootAlpha
        )
        let a0 = (amplitude + 1)
            - (amplitude - 1) * values.cosine
            + twoRootAlpha
        let a1 = 2 * (
            (amplitude - 1)
                - (amplitude + 1) * values.cosine
        )
        let a2 = (amplitude + 1)
            - (amplitude - 1) * values.cosine
            - twoRootAlpha

        return normalized(
            b0: b0,
            b1: b1,
            b2: b2,
            a0: a0,
            a1: a1,
            a2: a2
        )
    }

    static func lowpass(
        frequency: Float,
        q: Float,
        sampleRate: Int
    ) -> Biquad {
        guard let values = Values(
            frequency: frequency,
            q: q,
            sampleRate: sampleRate
        ) else {
            return bypass()
        }

        let b0 = (1 - values.cosine) / 2
        let b1 = 1 - values.cosine
        let b2 = (1 - values.cosine) / 2
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

    static func highpass(
        frequency: Float,
        q: Float,
        sampleRate: Int
    ) -> Biquad {
        guard let values = Values(
            frequency: frequency,
            q: q,
            sampleRate: sampleRate
        ) else {
            return bypass()
        }

        let b0 = (1 + values.cosine) / 2
        let b1 = -(1 + values.cosine)
        let b2 = (1 + values.cosine) / 2
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

    static func bandpass(
        frequency: Float,
        q: Float,
        sampleRate: Int
    ) -> Biquad {
        guard let values = Values(
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
    ) -> Biquad {
        guard a0 != 0,
              a0.isFinite else {
            return bypass()
        }

        return Biquad(
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0
        )
    }

    static func bypass() -> Biquad {
        Biquad(
            b0: 1,
            b1: 0,
            b2: 0,
            a1: 0,
            a2: 0
        )
    }
}

private struct Values {
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
