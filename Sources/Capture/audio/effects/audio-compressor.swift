import Darwin
import Foundation

public enum AudioCompressor {}

public struct AudioCompressorFactory: Sendable {
    public init() {}

    public func standard(
        thresholdDB: Float = -18,
        ratio: Float = 3,
        attackMS: Float = 8,
        releaseMS: Float = 120,
        kneeDB: Float = 6,
        makeupDB: Float = 0,
        detector: AudioCompressor.Detector = .rms(
            windowMS: 10
        ),
        sidechain: AudioCompressor.Sidechain = .none
    ) -> AudioCompressor.Standard {
        AudioCompressor.Standard(
            thresholdDB: thresholdDB,
            ratio: ratio,
            attackMS: attackMS,
            releaseMS: releaseMS,
            kneeDB: kneeDB,
            makeupDB: makeupDB,
            detector: detector,
            sidechain: sidechain
        )
    }

    public func softknee(
        thresholdDB: Float = -18,
        ratio: Float = 3,
        attackMS: Float = 8,
        releaseMS: Float = 120,
        kneeDB: Float = 8,
        makeupDB: Float = 0,
        detector: AudioCompressor.Detector = .rms(
            windowMS: 10
        ),
        sidechain: AudioCompressor.Sidechain = .none
    ) -> AudioCompressor.Standard {
        standard(
            thresholdDB: thresholdDB,
            ratio: ratio,
            attackMS: attackMS,
            releaseMS: releaseMS,
            kneeDB: kneeDB,
            makeupDB: makeupDB,
            detector: detector,
            sidechain: sidechain
        )
    }

    public func vintage(
        thresholdDB: Float = -23,
        ratio: Float = 2.5,
        attackMS: Float = 14,
        releaseMS: Float = 180,
        kneeDB: Float = 9,
        makeupDB: Float = 2,
        detector: AudioCompressor.Detector = .rms(
            windowMS: 14
        ),
        sidechain: AudioCompressor.Sidechain = .none,
        driveDB: Float = 4,
        harmonics: AudioCompressor.Harmonics = .tube,
        outputDB: Float = -1
    ) -> AudioCompressor.Vintage {
        AudioCompressor.Vintage(
            thresholdDB: thresholdDB,
            ratio: ratio,
            attackMS: attackMS,
            releaseMS: releaseMS,
            kneeDB: kneeDB,
            makeupDB: makeupDB,
            detector: detector,
            sidechain: sidechain,
            driveDB: driveDB,
            harmonics: harmonics,
            outputDB: outputDB
        )
    }
}

public extension AudioCompressor {
    enum Detector: Sendable, Hashable {
        case peak
        case rms(windowMS: Float)
    }

    enum Harmonics: Sendable, Hashable {
        case tape
        case tube
        case transformer
    }

    struct Sidechain: Sendable, Hashable {
        public static let none = Sidechain()

        public let highpassFrequency: Float?
        public let lowpassFrequency: Float?

        public init(
            highpassFrequency: Float? = nil,
            lowpassFrequency: Float? = nil
        ) {
            self.highpassFrequency = highpassFrequency
            self.lowpassFrequency = lowpassFrequency
        }

        public static func filtered(
            highpassFrequency: Float? = nil,
            lowpassFrequency: Float? = nil
        ) -> Sidechain {
            Sidechain(
                highpassFrequency: highpassFrequency,
                lowpassFrequency: lowpassFrequency
            )
        }
    }

    struct Standard: AudioProcessor {
        public let thresholdDB: Float
        public let ratio: Float
        public let attackMS: Float
        public let releaseMS: Float
        public let kneeDB: Float
        public let makeupDB: Float
        public let detector: AudioCompressor.Detector
        public let sidechain: AudioCompressor.Sidechain

        private var states: [AudioCompressorChannelState] = []
        private var preparedSampleRate: Int?
        private var preparedChannelCount: Int?

        public init(
            thresholdDB: Float = -18,
            ratio: Float = 3,
            attackMS: Float = 8,
            releaseMS: Float = 120,
            kneeDB: Float = 6,
            makeupDB: Float = 0,
            detector: AudioCompressor.Detector = .rms(
                windowMS: 10
            ),
            sidechain: AudioCompressor.Sidechain = .none
        ) {
            self.thresholdDB = thresholdDB
            self.ratio = ratio
            self.attackMS = attackMS
            self.releaseMS = releaseMS
            self.kneeDB = kneeDB
            self.makeupDB = makeupDB
            self.detector = detector
            self.sidechain = sidechain
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            let configuration = AudioCompressorConfiguration(
                thresholdDB: thresholdDB,
                ratio: ratio,
                attackMS: attackMS,
                releaseMS: releaseMS,
                kneeDB: kneeDB,
                makeupDB: makeupDB,
                detector: detector,
                sidechain: sidechain
            )

            prepare(
                buffer: buffer,
                configuration: configuration
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
                    configuration: configuration,
                    sampleRate: sampleRate
                )
            }

            states = localStates

            return processed
        }
    }

    struct Vintage: AudioProcessor {
        public let driveDB: Float
        public let harmonics: AudioCompressor.Harmonics
        public let outputDB: Float

        private var compressor: AudioCompressor.Standard

        public init(
            thresholdDB: Float = -23,
            ratio: Float = 2.5,
            attackMS: Float = 14,
            releaseMS: Float = 180,
            kneeDB: Float = 9,
            makeupDB: Float = 2,
            detector: AudioCompressor.Detector = .rms(
                windowMS: 14
            ),
            sidechain: AudioCompressor.Sidechain = .none,
            driveDB: Float = 4,
            harmonics: AudioCompressor.Harmonics = .tube,
            outputDB: Float = -1
        ) {
            self.compressor = AudioCompressor.Standard(
                thresholdDB: thresholdDB,
                ratio: ratio,
                attackMS: attackMS,
                releaseMS: releaseMS,
                kneeDB: kneeDB,
                makeupDB: makeupDB,
                detector: detector,
                sidechain: sidechain
            )
            self.driveDB = driveDB
            self.harmonics = harmonics
            self.outputDB = outputDB
        }

        public mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer {
            let compressed = try compressor.process(
                buffer
            )
            let outputGain = AudioCompressorMath.dbToLinear(
                outputDB
            )

            return compressed.mapFloatSamples { sample in
                AudioCompressorMath.saturate(
                    sample,
                    driveDB: driveDB,
                    harmonics: harmonics
                ) * outputGain
            }
        }
    }
}

private extension AudioCompressor.Standard {
    mutating func prepare(
        buffer: CaptureAudioInputBuffer,
        configuration: AudioCompressorConfiguration
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
            AudioCompressorChannelState(
                configuration: configuration,
                sampleRate: buffer.sampleRate
            )
        }

        preparedSampleRate = buffer.sampleRate
        preparedChannelCount = buffer.channelCount
    }
}

private struct AudioCompressorConfiguration: Sendable {
    let thresholdDB: Float
    let ratio: Float
    let attackMS: Float
    let releaseMS: Float
    let kneeDB: Float
    let makeupDB: Float
    let detector: AudioCompressor.Detector
    let sidechain: AudioCompressor.Sidechain
}

private struct AudioCompressorChannelState: Sendable {
    private var envelope: Float = 0
    private var rmsPower: Float = 0
    private var highpass: AudioCompressorHighpass?
    private var lowpass: AudioCompressorLowpass?

    init(
        configuration: AudioCompressorConfiguration,
        sampleRate: Int
    ) {
        if let frequency = configuration.sidechain.highpassFrequency,
           frequency > 0 {
            self.highpass = AudioCompressorHighpass(
                frequency: frequency,
                sampleRate: sampleRate
            )
        }

        if let frequency = configuration.sidechain.lowpassFrequency,
           frequency > 0 {
            self.lowpass = AudioCompressorLowpass(
                frequency: frequency,
                sampleRate: sampleRate
            )
        }
    }

    mutating func process(
        _ sample: Float,
        configuration: AudioCompressorConfiguration,
        sampleRate: Int
    ) -> Float {
        let detectorSample = processSidechain(
            sample
        )
        let detectedLevel = level(
            detectorSample,
            detector: configuration.detector,
            sampleRate: sampleRate
        )
        let coefficient = detectedLevel > envelope
            ? AudioCompressorMath.smoothingCoefficient(
                milliseconds: configuration.attackMS,
                sampleRate: sampleRate
            )
            : AudioCompressorMath.smoothingCoefficient(
                milliseconds: configuration.releaseMS,
                sampleRate: sampleRate
            )

        envelope = coefficient * envelope
            + (1 - coefficient) * detectedLevel

        let levelDB = AudioCompressorMath.linearToDB(
            envelope
        )
        let gainReductionDB = AudioCompressorMath.gainReductionDB(
            levelDB: levelDB,
            thresholdDB: configuration.thresholdDB,
            ratio: configuration.ratio,
            kneeDB: configuration.kneeDB
        )
        let gain = AudioCompressorMath.dbToLinear(
            gainReductionDB + configuration.makeupDB
        )

        return sample * gain
    }

    mutating func processSidechain(
        _ sample: Float
    ) -> Float {
        var output = sample

        if var filter = highpass {
            output = filter.process(
                output
            )
            highpass = filter
        }

        if var filter = lowpass {
            output = filter.process(
                output
            )
            lowpass = filter
        }

        return output
    }

    mutating func level(
        _ sample: Float,
        detector: AudioCompressor.Detector,
        sampleRate: Int
    ) -> Float {
        switch detector {
        case .peak:
            return abs(
                sample
            )

        case .rms(let windowMS):
            let coefficient = AudioCompressorMath.smoothingCoefficient(
                milliseconds: max(
                    0.1,
                    windowMS
                ),
                sampleRate: sampleRate
            )
            let power = sample * sample

            rmsPower = coefficient * rmsPower
                + (1 - coefficient) * power

            return sqrtf(
                max(
                    0,
                    rmsPower
                )
            )
        }
    }
}

private struct AudioCompressorHighpass: Sendable {
    private let coefficient: Float
    private var previousInput: Float = 0
    private var previousOutput: Float = 0

    init(
        frequency: Float,
        sampleRate: Int
    ) {
        self.coefficient = expf(
            -2 * Float.pi * frequency / Float(
                max(
                    1,
                    sampleRate
                )
            )
        )
    }

    mutating func process(
        _ input: Float
    ) -> Float {
        let output = coefficient * (
            previousOutput + input - previousInput
        )

        previousInput = input
        previousOutput = output

        return output
    }
}

private struct AudioCompressorLowpass: Sendable {
    private let coefficient: Float
    private var previousOutput: Float = 0

    init(
        frequency: Float,
        sampleRate: Int
    ) {
        self.coefficient = 1 - expf(
            -2 * Float.pi * frequency / Float(
                max(
                    1,
                    sampleRate
                )
            )
        )
    }

    mutating func process(
        _ input: Float
    ) -> Float {
        previousOutput += coefficient * (
            input - previousOutput
        )

        return previousOutput
    }
}

private enum AudioCompressorMath {
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
        guard milliseconds > 0,
              sampleRate > 0 else {
            return 0
        }

        let seconds = milliseconds / 1_000

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
        kneeDB: Float
    ) -> Float {
        let safeRatio = max(
            1,
            ratio
        )

        guard safeRatio > 1 else {
            return 0
        }

        let over = levelDB - thresholdDB
        let slope = 1 / safeRatio - 1
        let knee = max(
            0,
            kneeDB
        )

        guard knee > 0 else {
            return over > 0
                ? slope * over
                : 0
        }

        let halfKnee = knee / 2

        if over <= -halfKnee {
            return 0
        }

        if over >= halfKnee {
            return slope * over
        }

        return slope * powf(
            over + halfKnee,
            2
        ) / (
            2 * knee
        )
    }

    static func saturate(
        _ sample: Float,
        driveDB: Float,
        harmonics: AudioCompressor.Harmonics
    ) -> Float {
        let drive = dbToLinear(
            driveDB
        )
        let input = sample * drive

        switch harmonics {
        case .tube:
            return tanhf(
                input
            ) / max(
                0.000_1,
                tanhf(
                    drive
                )
            )

        case .tape:
            let scale: Float = 1.45

            return atanf(
                input * scale
            ) / max(
                0.000_1,
                atanf(
                    drive * scale
                )
            )

        case .transformer:
            let asymmetry: Float = 0.12
            let shaped = tanhf(
                input + asymmetry
            ) - tanhf(
                asymmetry
            )
            let normalizer = tanhf(
                drive + asymmetry
            ) - tanhf(
                asymmetry
            )

            return shaped / max(
                0.000_1,
                normalizer
            )
        }
    }
}
