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
                .peak(
                    frequency: 110,
                    gain: low,
                    q: 0.7
                ),
                .peak(
                    frequency: 3_600,
                    gain: mid,
                    q: 1
                ),
                .peak(
                    frequency: 12_000,
                    gain: high,
                    q: 0.7
                ),
            ]
        )
    }
}

public extension AudioEqualizer {
    struct Band: Sendable, Hashable {
        public enum Kind: Sendable, Hashable {
            case peak
        }

        public let kind: Kind
        public let frequency: Float
        public let gain: Float
        public let q: Float

        public init(
            kind: Kind,
            frequency: Float,
            gain: Float,
            q: Float
        ) {
            self.kind = kind
            self.frequency = frequency
            self.gain = gain
            self.q = q
        }

        public static func peak(
            frequency: Float,
            gain: Float,
            q: Float = 1
        ) -> AudioEqualizer.Band {
            AudioEqualizer.Band(
                kind: .peak,
                frequency: frequency,
                gain: gain,
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
        case .peak:
            return peak(
                frequency: band.frequency,
                gain: band.gain,
                q: band.q,
                sampleRate: sampleRate
            )
        }
    }

    static func peak(
        frequency: Float,
        gain: Float,
        q: Float,
        sampleRate: Int
    ) -> Biquad {
        guard sampleRate > 0,
              frequency > 0,
              q > 0 else {
            return bypass()
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

        let amplitude = Float(
            pow(
                10.0,
                Double(
                    gain / 40
                )
            )
        )
        let omega = 2 * Float.pi * safeFrequency / Float(
            sampleRate
        )
        let sine = sinf(
            omega
        )
        let cosine = cosf(
            omega
        )
        let alpha = sine / (2 * q)

        let b0 = 1 + alpha * amplitude
        let b1 = -2 * cosine
        let b2 = 1 - alpha * amplitude
        let a0 = 1 + alpha / amplitude
        let a1 = -2 * cosine
        let a2 = 1 - alpha / amplitude

        guard a0 != 0 else {
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
