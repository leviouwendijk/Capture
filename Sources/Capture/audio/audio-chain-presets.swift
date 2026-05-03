import Arguments
import Foundation

public enum AudioChainPreset: String, Sendable, Codable, Hashable, CaseIterable, ArgumentValue {
    case none
    case voice

    public var chain: AudioChain {
        switch self {
        case .none:
            return .raw

        case .voice:
            return .voice()
        }
    }
}

public extension AudioChain {
    static func preset(
        _ preset: AudioChainPreset
    ) -> AudioChain {
        preset.chain
    }

    static func voice(
        inputGainDB: Float = 5,
        gateFloorDB: Float = -74,
        gateOpenDB: Float = -52,
        outputCeilingDB: Float = -2
    ) -> AudioChain {
        AudioChain {
            A.gain.db(
                inputGainDB
            )

            A.equalizer.parametric(
                bands: [
                    .lowcut(
                        frequency: 70,
                        q: 0.707
                    ),
                    .highcut(
                        frequency: 15_000,
                        q: 0.707
                    ),
                ]
            )

            A.gate.softDB(
                floorDB: gateFloorDB,
                openDB: gateOpenDB,
                attackMS: 2,
                releaseMS: 180
            )

            A.leveller.standard(
                targetLevelDB: -23,
                activityThresholdDB: -48,
                deadbandDB: 2,
                maxBoostDB: 6,
                maxCutDB: 11,
                attackMS: 15,
                releaseMS: 1_000,
                holdMS: 220,
                windowMS: 220,
                detectorHighpassFrequency: 140
            )

            A.compressor.softknee(
                thresholdDB: -25,
                ratio: 2.5,
                attackMS: 10,
                releaseMS: 300,
                kneeDB: 8,
                makeupDB: 0,
                detector: .rms(
                    windowMS: 10
                ),
            )

            A.equalizer.parametric(
                bands: [
                    .shelf(
                        .low,
                        frequency: 110,
                        gain: 5.0,
                        q: 0.4
                    ),
                    .bell(
                        frequency: 110,
                        gain: 5.0,
                        q: 0.3
                    ),
                    .lowcut(
                        frequency: 130,
                        q: 0.5
                    ),
                    .bell(
                        frequency: 220,
                        gain: 2.0,
                        q: 0.7
                    ),
                    .bell(
                        frequency: 350,
                        gain: -1.0,
                        q: 0.8
                    ),
                    .bell(
                        frequency: 650,
                        gain: -1.0,
                        q: 0.7
                    ),
                    .bell(
                        frequency: 3_200,
                        gain: 0.75,
                        q: 0.9
                    ),
                    .highcut(
                        frequency: 18_000,
                        q: 0.707
                    ),
                ]
            )

            A.deesser.vocal(
                frequency: 6_500,
                thresholdDB: -34,
                maxReductionDB: 7
            )

            A.compressor.softknee(
                thresholdDB: -15,
                ratio: 3.8,
                attackMS: 12,
                releaseMS: 150,
                kneeDB: 10,
                makeupDB: 0,
                detector: .rms(
                    windowMS: 10
                ),
                sidechain: .filtered(
                    highpassFrequency: 100
                )
            )

            A.limiter.db(
                ceilingDB: outputCeilingDB,
                kneeDB: 2
            )
        }
    }
}
