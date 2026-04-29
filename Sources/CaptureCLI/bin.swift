import Arguments
import Capture
import Foundation
import Terminal

@main
enum CaptureCLI {
    static func main() async {
        do {
            try await application().run(
                Array(
                    CommandLine.arguments.dropFirst()
                )
            )
        } catch {
            fputs(
                "capture: \(error.localizedDescription)\n",
                stderr
            )
            Foundation.exit(1)
        }
    }
}

private extension CaptureCLI {
    static func spec() throws -> CommandSpec {
        try cmd("capture") {
            about("Native macOS screen and audio capture.")
            discussion("Records screen video and CoreAudio-backed microphone input.")

            try cmd("devices") {
                about("List available capture devices.")
            }

            try cmd("audio") {
                about("Record microphone audio to a WAV file.")

                opt(
                    "audio",
                    short: "a",
                    as: String.self,
                    help: "Audio input device name or identifier."
                )

                opt(
                    "output",
                    short: "o",
                    as: String.self,
                    arity: .required,
                    help: "Output .wav file."
                )

                opt(
                    "duration",
                    short: "d",
                    as: Int.self,
                    help: "Duration in seconds."
                )

                opt(
                    "sample-rate",
                    as: Int.self,
                    help: "Audio sample rate."
                )

                opt(
                    "channel",
                    as: Int.self,
                    help: "Audio channel count."
                )

                example(
                    "capture audio --audio ext-in --duration 5 --output /tmp/ext-in.wav"
                )
            }

            try cmd("video") {
                about("Record screen video without audio.")

                opt(
                    "output",
                    short: "o",
                    as: String.self,
                    arity: .required,
                    help: "Output .mov or .mp4 file."
                )

                opt(
                    "duration",
                    short: "d",
                    as: Int.self,
                    help: "Duration in seconds."
                )

                opt(
                    "width",
                    as: Int.self,
                    help: "Video width."
                )

                opt(
                    "height",
                    as: Int.self,
                    help: "Video height."
                )

                opt(
                    "fps",
                    as: Int.self,
                    help: "Video frame rate."
                )

                flag(
                    "cursor",
                    help: "Show the cursor."
                )

                example(
                    "capture video --duration 5 --output /tmp/capture-video.mov"
                )
            }

            try cmd("record") {
                about("Record screen and audio.")

                opt(
                    "audio",
                    short: "a",
                    as: String.self,
                    help: "Audio input device name or identifier."
                )

                opt(
                    "output",
                    short: "o",
                    as: String.self,
                    arity: .required,
                    help: "Output .mov or .mp4 file."
                )

                opt(
                    "duration",
                    short: "d",
                    as: Int.self,
                    help: "Duration in seconds."
                )

                opt(
                    "width",
                    as: Int.self,
                    help: "Video width."
                )

                opt(
                    "height",
                    as: Int.self,
                    help: "Video height."
                )

                opt(
                    "fps",
                    as: Int.self,
                    help: "Video frame rate."
                )

                flag(
                    "cursor",
                    help: "Show the cursor."
                )

                example(
                    "capture record --audio ext-in --duration 5 --output ~/Desktop/recording.mov"
                )
            }

            try cmd("help") {
                about("Show help.")
            }
        }
    }

    static func application() throws -> ArgumentApplication {
        let spec = try spec()

        return ArgumentApplication(
            spec: spec
        ) {
            defaultCommand { _ in
                print(
                    ArgumentHelpRenderer().render(
                        command: spec
                    )
                )
            }

            command("help") { _ in
                print(
                    ArgumentHelpRenderer().render(
                        command: spec
                    )
                )
            }

            command("devices") { _ in
                try await printDevices(
                    provider: MacCaptureDeviceProvider()
                )
            }

            command("audio") { invocation in
                try await recordAudio(
                    invocation: invocation
                )
            }

            command("video") { invocation in
                try await recordVideo(
                    invocation: invocation
                )
            }

            command("record") { invocation in
                try await record(
                    invocation: invocation
                )
            }
        }
    }

    static func printDevices(
        provider: CaptureDeviceProvider
    ) async throws {
        let displays = try await provider.displays()
        let audioInputs = try await provider.audioInputs()

        let document = TerminalDetailDocument(
            title: "Capture Devices",
            sections: [
                .init(
                    title: "Displays",
                    items: [
                        .list(
                            label: "devices",
                            values: labels(
                                for: displays
                            )
                        ),
                    ]
                ),
                .init(
                    title: "Audio Inputs",
                    items: [
                        .list(
                            label: "devices",
                            values: labels(
                                for: audioInputs
                            )
                        ),
                    ]
                ),
            ],
            layout: .agentic
        )

        fputs(
            document.render(),
            stderr
        )
    }

    static func labels(
        for devices: [CaptureDevice]
    ) -> [String] {
        guard !devices.isEmpty else {
            return [
                "none",
            ]
        }

        return devices.map(\.label)
    }

    static func recordAudio(
        invocation: ParsedInvocation
    ) async throws {
        let outputString = try invocation.value(
            "output",
            as: String.self
        ).unwrap(
            message: "Missing --output."
        )

        let audioName = try invocation.value(
            "audio",
            as: String.self
        ) ?? "ext-in"

        let durationSeconds = try invocation.value(
            "duration",
            as: Int.self
        ) ?? 5

        let sampleRate = try invocation.value(
            "sample-rate",
            as: Int.self
        ) ?? 48_000

        let channel = try invocation.value(
            "channel",
            as: Int.self
        ) ?? 1

        let audio = try CaptureAudioOptions(
            device: .name(
                audioName
            ),
            sampleRate: sampleRate,
            channel: channel,
            codec: .pcm
        )

        let configuration = try CaptureConfiguration(
            video: CaptureVideoOptions(),
            audio: audio,
            output: URL(
                fileURLWithPath: outputString.expandingTilde()
            )
        )

        let options = try CaptureAudioRecordOptions(
            durationSeconds: durationSeconds
        )

        let result = try await CoreAudioRecorder().recordAudio(
            configuration: configuration,
            options: options
        )

        fputs(
            "capture: wrote audio \(result.output.path)\n",
            stderr
        )
    }

    static func recordVideo(
        invocation: ParsedInvocation
    ) async throws {
        let outputString = try invocation.value(
            "output",
            as: String.self
        ).unwrap(
            message: "Missing --output."
        )

        let output = URL(
            fileURLWithPath: outputString.expandingTilde()
        )

        let durationSeconds = try invocation.value(
            "duration",
            as: Int.self
        ) ?? 5

        let width = try invocation.value(
            "width",
            as: Int.self
        ) ?? 1920

        let height = try invocation.value(
            "height",
            as: Int.self
        ) ?? 1080

        let fps = try invocation.value(
            "fps",
            as: Int.self
        ) ?? 24

        let cursor = try invocation.flag(
            "cursor",
            default: true
        )

        let video = try CaptureVideoOptions(
            width: width,
            height: height,
            fps: fps,
            cursor: cursor
        )

        let configuration = try CaptureConfiguration(
            video: video,
            audio: CaptureAudioOptions(),
            container: try container(
                for: output
            ),
            output: output
        )

        let options = try CaptureVideoRecordOptions(
            durationSeconds: durationSeconds
        )

        let result = try await ScreenCaptureVideoRecorder().recordVideo(
            configuration: configuration,
            options: options
        )

        fputs(
            "capture: wrote video \(result.output.path) frames=\(result.frameCount)\n",
            stderr
        )
    }

    static func record(
        invocation: ParsedInvocation
    ) async throws {
        let outputString = try invocation.value(
            "output",
            as: String.self
        ).unwrap(
            message: "Missing --output."
        )

        let output = URL(
            fileURLWithPath: outputString.expandingTilde()
        )

        let durationSeconds = try invocation.value(
            "duration",
            as: Int.self
        ) ?? 5

        let width = try invocation.value(
            "width",
            as: Int.self
        ) ?? 1920

        let height = try invocation.value(
            "height",
            as: Int.self
        ) ?? 1080

        let fps = try invocation.value(
            "fps",
            as: Int.self
        ) ?? 24

        let audioName = try invocation.value(
            "audio",
            as: String.self
        ) ?? "ext-in"

        let cursor = try invocation.flag(
            "cursor",
            default: true
        )

        let video = try CaptureVideoOptions(
            width: width,
            height: height,
            fps: fps,
            cursor: cursor
        )

        let audio = try CaptureAudioOptions(
            device: .name(
                audioName
            )
        )

        let configuration = try CaptureConfiguration(
            video: video,
            audio: audio,
            container: try container(
                for: output
            ),
            output: output
        )

        let options = try CaptureRecordOptions(
            durationSeconds: durationSeconds
        )

        let session = CaptureSession(
            configuration: configuration,
            options: options
        )

        let result = try await session.start()

        fputs(
            "capture: wrote recording \(result.output.path) frames=\(result.videoFrameCount)\n",
            stderr
        )
    }

    static func container(
        for output: URL
    ) throws -> CaptureContainer {
        switch output.pathExtension.lowercased() {
        case "mov":
            return .mov

        case "mp4":
            return .mp4

        default:
            throw CaptureError.videoCapture(
                "Video output must end in .mov or .mp4."
            )
        }
    }
}
