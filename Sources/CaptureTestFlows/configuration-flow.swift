import Capture
import Foundation
import TestFlows

extension CaptureFlowSuite {
    static var configurationFlow: TestFlow {
        TestFlow(
            "configuration",
            tags: [
                "model",
                "configuration",
            ]
        ) {
            Step("valid default-ish configuration parses") {
                let video = try CaptureVideoOptions()
                let audio = try CaptureAudioOptions(
                    device: .name(
                        "ext-in"
                    )
                )
                let output = URL(
                    fileURLWithPath: "/tmp/capture-test.mov"
                )
                let configuration = try CaptureConfiguration(
                    video: video,
                    audio: audio,
                    output: output
                )

                try Expect.equal(
                    configuration.video.width,
                    1920,
                    "video.width"
                )
                try Expect.equal(
                    configuration.video.height,
                    1080,
                    "video.height"
                )
                try Expect.equal(
                    configuration.video.fps,
                    24,
                    "video.fps"
                )
                try Expect.equal(
                    configuration.audio.sampleRate,
                    48_000,
                    "audio.sampleRate"
                )
                try Expect.equal(
                    configuration.audio.channel,
                    1,
                    "audio.channel"
                )
                try Expect.equal(
                    configuration.container,
                    .mov,
                    "container"
                )
            }

            Step("valid audio record options parse") {
                let options = try CaptureAudioRecordOptions(
                    durationSeconds: 5
                )

                try Expect.equal(
                    options.durationSeconds,
                    5,
                    "audio-record.duration"
                )
            }

            Step("valid video record options parse") {
                let options = try CaptureVideoRecordOptions(
                    durationSeconds: 5
                )

                try Expect.equal(
                    options.durationSeconds,
                    5,
                    "video-record.duration"
                )
            }

            Step("valid combined record options parse") {
                let options = try CaptureRecordOptions(
                    durationSeconds: 5
                )

                try Expect.equal(
                    options.durationSeconds,
                    5,
                    "record.duration"
                )
            }

            Step("invalid video size throws") {
                try Expect.throwsError(
                    "video.invalid-size"
                ) {
                    _ = try CaptureVideoOptions(
                        width: 0,
                        height: 1080
                    )
                }
            }

            Step("invalid frame rate throws") {
                try Expect.throwsError(
                    "video.invalid-fps"
                ) {
                    _ = try CaptureVideoOptions(
                        fps: 0
                    )
                }
            }

            Step("invalid sample rate throws") {
                try Expect.throwsError(
                    "audio.invalid-sample-rate"
                ) {
                    _ = try CaptureAudioOptions(
                        sampleRate: 0
                    )
                }
            }

            Step("invalid channel throws") {
                try Expect.throwsError(
                    "audio.invalid-channel"
                ) {
                    _ = try CaptureAudioOptions(
                        channel: 0
                    )
                }
            }

            Step("invalid audio record duration throws") {
                try Expect.throwsError(
                    "audio-record.invalid-duration"
                ) {
                    _ = try CaptureAudioRecordOptions(
                        durationSeconds: 0
                    )
                }
            }

            Step("invalid video record duration throws") {
                try Expect.throwsError(
                    "video-record.invalid-duration"
                ) {
                    _ = try CaptureVideoRecordOptions(
                        durationSeconds: 0
                    )
                }
            }

            Step("invalid combined record duration throws") {
                try Expect.throwsError(
                    "record.invalid-duration"
                ) {
                    _ = try CaptureRecordOptions(
                        durationSeconds: 0
                    )
                }
            }
        }
    }
}
