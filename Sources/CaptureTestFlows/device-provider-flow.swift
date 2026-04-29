import Capture
import Foundation
import TestFlows

extension CaptureFlowSuite {
    static var deviceProviderFlow: TestFlow {
        TestFlow(
            "device-provider",
            tags: [
                "devices",
                "provider",
            ]
        ) {
            Step("static provider returns fixture devices") {
                let provider = fixtureProvider()

                let displays = try await provider.displays()
                let audioInputs = try await provider.audioInputs()

                try Expect.equal(
                    displays.map(\.label),
                    [
                        "Main Display    1920x1080    id=display-1",
                    ],
                    "provider.displays.labels"
                )

                try Expect.equal(
                    audioInputs.map(\.label),
                    [
                        "ext-in    48000 Hz    id=audio-1",
                    ],
                    "provider.audio.labels"
                )
            }

            Step("device label omits empty detail") {
                let device = CaptureDevice(
                    id: "device-1",
                    name: "Input",
                    kind: .audio_input
                )

                try Expect.equal(
                    device.label,
                    "Input    id=device-1",
                    "device.label.no-detail"
                )
            }

            Step("resolver maps main display and named audio input") {
                let configuration = try fixtureConfiguration(
                    audio: .name(
                        "ext-in"
                    )
                )
                let resolver = CaptureDeviceResolver(
                    provider: fixtureProvider()
                )

                let resolved = try await resolver.resolve(
                    configuration: configuration
                )

                try Expect.equal(
                    resolved.display.id,
                    "display-1",
                    "resolver.display.id"
                )

                try Expect.equal(
                    resolved.audioInput.id,
                    "audio-1",
                    "resolver.audio.id"
                )
            }

            Step("resolver accepts audio identifier through name input") {
                let configuration = try fixtureConfiguration(
                    audio: .name(
                        "audio-1"
                    )
                )
                let resolver = CaptureDeviceResolver(
                    provider: fixtureProvider()
                )

                let resolved = try await resolver.resolve(
                    configuration: configuration
                )

                try Expect.equal(
                    resolved.audioInput.name,
                    "ext-in",
                    "resolver.audio.identifier-via-name"
                )
            }

            Step("resolver rejects missing audio input") {
                let configuration = try fixtureConfiguration(
                    audio: .name(
                        "missing-input"
                    )
                )
                let resolver = CaptureDeviceResolver(
                    provider: fixtureProvider()
                )

                try await Expect.throwsError(
                    "resolver.audio.missing"
                ) {
                    _ = try await resolver.resolve(
                        configuration: configuration
                    )
                }
            }

            Step("resolver rejects invalid display index") {
                let configuration = try CaptureConfiguration(
                    display: .index(
                        42
                    ),
                    video: CaptureVideoOptions(),
                    audio: CaptureAudioOptions(
                        device: .name(
                            "ext-in"
                        )
                    ),
                    output: URL(
                        fileURLWithPath: "/tmp/capture-test.mov"
                    )
                )
                let resolver = CaptureDeviceResolver(
                    provider: fixtureProvider()
                )

                try await Expect.throwsError(
                    "resolver.display.invalid-index"
                ) {
                    _ = try await resolver.resolve(
                        configuration: configuration
                    )
                }
            }
        }
    }

    static func fixtureProvider() -> StaticCaptureDeviceProvider {
        StaticCaptureDeviceProvider(
            displays: [
                .init(
                    id: "display-1",
                    name: "Main Display",
                    kind: .display,
                    detail: "1920x1080"
                ),
            ],
            audioInputs: [
                .init(
                    id: "audio-1",
                    name: "ext-in",
                    kind: .audio_input,
                    detail: "48000 Hz"
                ),
            ]
        )
    }

    static func fixtureConfiguration(
        audio: CaptureAudioDevice
    ) throws -> CaptureConfiguration {
        try CaptureConfiguration(
            video: CaptureVideoOptions(),
            audio: CaptureAudioOptions(
                device: audio
            ),
            output: URL(
                fileURLWithPath: "/tmp/capture-test.mov"
            )
        )
    }
}
