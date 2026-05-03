import Darwin
import Foundation

public enum AudioLeveller {}

public struct AudioLevellerFactory: Sendable {
    public init() {}

    public func standard(
        targetLevelDB: Float = -22,
        activityThresholdDB: Float = -48,
        deadbandDB: Float = 2,
        maxBoostDB: Float = 8,
        maxCutDB: Float = 12,
        attackMS: Float = 70,
        releaseMS: Float = 850,
        holdMS: Float = 180,
        windowMS: Float = 180,
        detectorHighpassFrequency: Float = 120
    ) -> AudioLeveller.Standard {
        AudioLeveller.Standard(
            targetLevelDB: targetLevelDB,
            activityThresholdDB: activityThresholdDB,
            deadbandDB: deadbandDB,
            maxBoostDB: maxBoostDB,
            maxCutDB: maxCutDB,
            attackMS: attackMS,
            releaseMS: releaseMS,
            holdMS: holdMS,
            windowMS: windowMS,
            detectorHighpassFrequency: detectorHighpassFrequency
        )
    }

    public func vocal(
        targetLevelDB: Float = -22,
        activityThresholdDB: Float = -48,
        maxBoostDB: Float = 7,
        maxCutDB: Float = 10
    ) -> AudioLeveller.Standard {
        standard(
            targetLevelDB: targetLevelDB,
            activityThresholdDB: activityThresholdDB,
            deadbandDB: 2,
            maxBoostDB: maxBoostDB,
            maxCutDB: maxCutDB,
            attackMS: 70,
            releaseMS: 850,
            holdMS: 180,
            windowMS: 180,
            detectorHighpassFrequency: 120
        )
    }

    public func broadcast(
        targetLevelDB: Float = -21,
        activityThresholdDB: Float = -50
    ) -> AudioLeveller.Standard {
        standard(
            targetLevelDB: targetLevelDB,
            activityThresholdDB: activityThresholdDB,
            deadbandDB: 1.5,
            maxBoostDB: 9,
            maxCutDB: 12,
            attackMS: 55,
            releaseMS: 1_000,
            holdMS: 220,
            windowMS: 220,
            detectorHighpassFrequency: 120
        )
    }

    public func gentle(
        targetLevelDB: Float = -23,
        activityThresholdDB: Float = -48
    ) -> AudioLeveller.Standard {
        standard(
            targetLevelDB: targetLevelDB,
            activityThresholdDB: activityThresholdDB,
            deadbandDB: 3,
            maxBoostDB: 5,
            maxCutDB: 7,
            attackMS: 100,
            releaseMS: 1_100,
            holdMS: 250,
            windowMS: 220,
            detectorHighpassFrequency: 120
        )
    }
}

public extension AudioLeveller {
    struct Standard: AudioProcessor {
        public let targetLevelDB: Float
        public let activityThresholdDB: Float
        public let deadbandDB: Float
        public let maxBoostDB: Float
        public let maxCutDB: Float
        public let attackMS: Float
        public let releaseMS: Float
        public let holdMS: Float
        public let windowMS: Float
        public let detectorHighpassFrequency: Float

        private var states: [AudioLevellerChannelState] = []
        private var preparedSampleRate: Int?
        private var preparedChannelCount: Int?

        public init(
            targetLevelDB: Float = -22,
            activityThresholdDB: Float = -48,
            deadbandDB: Float = 2,
            maxBoostDB: Float = 8,
            maxCutDB: Float = 12,
            attackMS: Float = 70,
            releaseMS: Float = 850,
            holdMS: Float = 180,
            windowMS: Float = 180,
            detectorHighpassFrequency: Float = 120
        ) {
            self.targetLevelDB = targetLevelDB
            self.activityThresholdDB = activityThresholdDB
            self.deadbandDB = deadbandDB
            self.maxBoostDB = maxBoostDB
            self.maxCutDB = maxCutDB
            self.attackMS = attackMS
            self.releaseMS = releaseMS
            self.holdMS = holdMS
            self.windowMS = windowMS
            self.detectorHighpassFrequency = detectorHighpassFrequency
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

            let configuration = AudioLevellerConfiguration(
                targetLevelDB: targetLevelDB,
                activityThresholdDB: activityThresholdDB,
                deadbandDB: deadbandDB,
                maxBoostDB: maxBoostDB,
                maxCutDB: maxCutDB,
                attackMS: attackMS,
                releaseMS: releaseMS,
                holdMS: holdMS,
                windowMS: windowMS
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

private extension AudioLeveller.Standard {
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
            AudioLevellerChannelState(
                detectorHighpassFrequency: detectorHighpassFrequency,
                sampleRate: buffer.sampleRate
            )
        }

        preparedSampleRate = buffer.sampleRate
        preparedChannelCount = buffer.channelCount
    }
}

private struct AudioLevellerConfiguration: Sendable {
    let targetLevelDB: Float
    let activityThresholdDB: Float
    let deadbandDB: Float
    let maxBoostDB: Float
    let maxCutDB: Float
    let attackMS: Float
    let releaseMS: Float
    let holdMS: Float
    let windowMS: Float
}

private struct AudioLevellerChannelState: Sendable {
    private var rmsPower: Float = 0
    private var gainDB: Float = 0
    private var heldGainDB: Float = 0
    private var holdSamplesRemaining: Int = 0
    private var detectorHighpass: AudioLevellerHighpass?

    init(
        detectorHighpassFrequency: Float,
        sampleRate: Int
    ) {
        if detectorHighpassFrequency > 0 {
            self.detectorHighpass = AudioLevellerHighpass(
                frequency: detectorHighpassFrequency,
                sampleRate: sampleRate
            )
        }
    }

    mutating func process(
        _ sample: Float,
        configuration: AudioLevellerConfiguration,
        sampleRate: Int
    ) -> Float {
        let detectorSample = processDetector(
            sample
        )
        let rmsCoefficient = AudioLevellerMath.smoothingCoefficient(
            milliseconds: configuration.windowMS,
            sampleRate: sampleRate
        )
        let power = detectorSample * detectorSample

        rmsPower = rmsCoefficient * rmsPower
            + (1 - rmsCoefficient) * power

        let level = sqrtf(
            max(
                0,
                rmsPower
            )
        )
        let levelDB = AudioLevellerMath.linearToDB(
            level
        )
        let targetGainDB = targetGain(
            levelDB: levelDB,
            configuration: configuration,
            sampleRate: sampleRate
        )
        let gainCoefficient = AudioLevellerMath.smoothingCoefficient(
            milliseconds: targetGainDB < gainDB
                ? configuration.attackMS
                : configuration.releaseMS,
            sampleRate: sampleRate
        )

        gainDB = gainCoefficient * gainDB
            + (1 - gainCoefficient) * targetGainDB

        return sample * AudioLevellerMath.dbToLinear(
            gainDB
        )
    }

    mutating func processDetector(
        _ sample: Float
    ) -> Float {
        guard var detectorHighpass else {
            return sample
        }

        let output = detectorHighpass.process(
            sample
        )

        self.detectorHighpass = detectorHighpass

        return output
    }

    mutating func targetGain(
        levelDB: Float,
        configuration: AudioLevellerConfiguration,
        sampleRate: Int
    ) -> Float {
        guard levelDB >= configuration.activityThresholdDB else {
            heldGainDB = min(
                0,
                heldGainDB
            )
            holdSamplesRemaining = 0

            return heldGainDB
        }

        let desiredGainDB = configuration.targetLevelDB - levelDB
        let deadband = max(
            0,
            configuration.deadbandDB
        )

        let resolvedGainDB: Float

        if abs(
            desiredGainDB
        ) <= deadband {
            resolvedGainDB = 0
        } else if desiredGainDB > 0 {
            resolvedGainDB = desiredGainDB - deadband
        } else {
            resolvedGainDB = desiredGainDB + deadband
        }

        let clampedGainDB = max(
            -max(
                0,
                configuration.maxCutDB
            ),
            min(
                max(
                    0,
                    configuration.maxBoostDB
                ),
                resolvedGainDB
            )
        )

        if clampedGainDB <= heldGainDB {
            heldGainDB = clampedGainDB
            holdSamplesRemaining = AudioLevellerMath.samples(
                milliseconds: configuration.holdMS,
                sampleRate: sampleRate
            )

            return heldGainDB
        }

        if holdSamplesRemaining > 0 {
            holdSamplesRemaining -= 1

            return heldGainDB
        }

        heldGainDB = clampedGainDB

        return heldGainDB
    }
}

private struct AudioLevellerHighpass: Sendable {
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

private enum AudioLevellerMath {
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

    static func samples(
        milliseconds: Float,
        sampleRate: Int
    ) -> Int {
        max(
            0,
            Int(
                milliseconds / 1_000 * Float(
                    max(
                        1,
                        sampleRate
                    )
                )
            )
        )
    }
}
