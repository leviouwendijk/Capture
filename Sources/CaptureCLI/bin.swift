import Arguments
import Capture
import Foundation
import Terminal
import Darwin

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

                opt(
                    "quality",
                    short: "q",
                    as: String.self,
                    help: "Video quality preset: compact, standard, high, archival."
                )

                opt(
                    "bitrate",
                    as: Int.self,
                    help: "Explicit video bitrate in bits per second. Overrides --quality."
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

                opt(
                    "quality",
                    as: String.self,
                    help: "Video quality preset: compact, standard, high, archival."
                )

                opt(
                    "bitrate",
                    as: Int.self,
                    help: "Explicit video bitrate in bits per second. Overrides --quality."
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

        let quality = try videoQuality(
            invocation: invocation
        )

        let bitrate = try invocation.value(
            "bitrate",
            as: Int.self
        )

        let cursor = try invocation.flag(
            "cursor",
            default: true
        )

        let video = try CaptureVideoOptions(
            width: width,
            height: height,
            fps: fps,
            cursor: cursor,
            quality: quality,
            bitrate: bitrate
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
            "capture: wrote video \(result.output.path) frames=\(result.frameCount) quality=\(video.quality.rawValue) bitrate=\(video.bitrate)\n",
            stderr
        )
    }

    static func recordingTimer(
        limitSeconds: Int?,
        output: URL,
        audioName: String,
        quality: CaptureVideoQuality,
        bitrate: Int
    ) -> TerminalLiveStatusLine {
        let modeLine: String

        if let limitSeconds {
            modeLine = "mode: fixed duration \(TerminalDurationFormatter.format(TimeInterval(limitSeconds)))"
        } else {
            modeLine = "mode: live"
        }

        let stopLine: String

        if limitSeconds == nil {
            stopLine = "stop: press q + Return, Ctrl-C, or send SIGTERM"
        } else {
            stopLine = "stop: waits for duration limit"
        }

        return TerminalLiveStatusLine(
            limitSeconds: limitSeconds.map(
                TimeInterval.init
            ),
            leadingLines: [
                "capture: recording",
                "output: \(output.path)",
                "audio: \(audioName)",
                "quality: \(quality.rawValue)",
                "bitrate: \(bitrate)",
                modeLine,
                stopLine,
            ]
        ) { frame in
            if let limitText = frame.limitText,
               let remainingText = frame.remainingText {
                return "time: \(frame.elapsedText) / \(limitText)    remaining: \(remainingText)"
            }

            return "time: \(frame.elapsedText)"
        }
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
        )

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

        let quality = try videoQuality(
            invocation: invocation
        )

        let bitrate = try invocation.value(
            "bitrate",
            as: Int.self
        )

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
            cursor: cursor,
            quality: quality,
            bitrate: bitrate
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

        if let durationSeconds {
            let session = try CaptureSession(
                configuration: configuration,
                options: CaptureRecordOptions(
                    durationSeconds: durationSeconds
                )
            )
            let timer = recordingTimer(
                limitSeconds: durationSeconds,
                output: output,
                audioName: audioName,
                quality: video.quality,
                bitrate: video.bitrate
            )

            await timer.start()

            do {
                let result = try await session.start()

                await timer.stop(
                    finalLine: "time: \(TerminalDurationFormatter.format(TimeInterval(result.durationSeconds)))"
                )

                fputs(
                    "capture: wrote recording \(result.output.path) duration=\(result.durationSeconds)s frames=\(result.videoFrameCount) quality=\(video.quality.rawValue) bitrate=\(video.bitrate)\n",
                    stderr
                )
            } catch {
                await timer.stop()
                throw error
            }
        } else {
            let stopSignal = CaptureStopSignal()
            let listener = CaptureCLIStopListener(
                stopSignal: stopSignal
            )
            let session = CaptureSession(
                configuration: configuration
            )
            let timer = recordingTimer(
                limitSeconds: nil,
                output: output,
                audioName: audioName,
                quality: video.quality,
                bitrate: video.bitrate
            )

            listener.start()
            await timer.start()

            do {
                let result = try await session.startUntilStopped(
                    stopSignal: stopSignal
                )

                await timer.stop(
                    finalLine: "time: \(TerminalDurationFormatter.format(TimeInterval(result.durationSeconds)))"
                )
                listener.stop()

                fputs(
                    "capture: wrote recording \(result.output.path) duration=\(result.durationSeconds)s frames=\(result.videoFrameCount) quality=\(video.quality.rawValue) bitrate=\(video.bitrate)\n",
                    stderr
                )
            } catch {
                await timer.stop()
                listener.stop()
                throw error
            }
        }
    }

    static func videoQuality(
        invocation: ParsedInvocation
    ) throws -> CaptureVideoQuality {
        let value = try invocation.value(
            "quality",
            as: String.self
        ) ?? CaptureVideoQuality.standard.rawValue

        guard let quality = CaptureVideoQuality(
            rawValue: value.lowercased()
        ) else {
            throw CaptureCLIError.invalidQuality(
                value: value,
                allowed: CaptureVideoQuality.allCases.map(\.rawValue)
            )
        }

        return quality
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

private final class CaptureCLIStopListener: @unchecked Sendable {
    private let stopSignal: CaptureStopSignal
    private let queue = DispatchQueue(
        label: "capture.cli.stop-listener"
    )

    private var interruptSource: DispatchSourceSignal?
    private var terminateSource: DispatchSourceSignal?
    private var inputTask: Task<Void, Never>?

    init(
        stopSignal: CaptureStopSignal
    ) {
        self.stopSignal = stopSignal
    }

    func start() {
        Darwin.signal(
            SIGINT,
            SIG_IGN
        )
        Darwin.signal(
            SIGTERM,
            SIG_IGN
        )

        let interruptSource = DispatchSource.makeSignalSource(
            signal: SIGINT,
            queue: queue
        )
        let terminateSource = DispatchSource.makeSignalSource(
            signal: SIGTERM,
            queue: queue
        )

        interruptSource.setEventHandler { [stopSignal] in
            stopSignal.stop()
        }
        terminateSource.setEventHandler { [stopSignal] in
            stopSignal.stop()
        }

        interruptSource.resume()
        terminateSource.resume()

        self.interruptSource = interruptSource
        self.terminateSource = terminateSource

        inputTask = Task.detached { [stopSignal] in
            while let line = readLine() {
                let value = line.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).lowercased()

                guard value == "q" else {
                    continue
                }

                stopSignal.stop()
                break
            }
        }
    }

    func stop() {
        interruptSource?.cancel()
        terminateSource?.cancel()
        inputTask?.cancel()

        Darwin.signal(
            SIGINT,
            SIG_DFL
        )
        Darwin.signal(
            SIGTERM,
            SIG_DFL
        )
    }
}
