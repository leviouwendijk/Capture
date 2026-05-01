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
        try cmd("capturer") {
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
                    help: "Video width. Defaults to selected display width. If used without --height, preserves display aspect ratio."
                )

                opt(
                    "height",
                    as: Int.self,
                    help: "Video height. Defaults to selected display height. If used without --width, preserves display aspect ratio."
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

            try cmd("camera") {
                about("Record camera video and microphone audio.")

                opt(
                    "camera",
                    short: "c",
                    as: String.self,
                    help: "Camera video input device name or identifier."
                )

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

                opt(
                    "mic-gain",
                    as: Double.self,
                    help: "Microphone gain multiplier. Defaults to 1.0."
                )

                example(
                    "capture camera --camera \"Studio Display Camera\" --audio ext-in --duration 5 --output ~/Desktop/camera.mov"
                )
            }

            try cmd("compose") {
                about("Record screen, camera, and audio into a composed layout.")

                opt(
                    "camera",
                    short: "c",
                    as: String.self,
                    help: "Camera video input device name or identifier."
                )

                opt(
                    "audio",
                    short: "a",
                    as: String.self,
                    help: "Audio input device name or identifier."
                )

                flag(
                    "system-audio",
                    help: "Capture system audio as a separate audio track."
                )

                opt(
                    "audio-layout",
                    as: String.self,
                    help: "Audio layout: separate or mixed. Defaults to separate."
                )

                opt(
                    "mic-gain",
                    as: Double.self,
                    help: "Microphone gain multiplier. Defaults to 1.0."
                )

                opt(
                    "system-gain",
                    as: Double.self,
                    help: "System audio gain multiplier. Defaults to 1.0."
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
                    help: "Composition canvas width. Defaults to selected display width."
                )

                opt(
                    "height",
                    as: Int.self,
                    help: "Composition canvas height. Defaults to selected display height."
                )

                opt(
                    "fps",
                    as: Int.self,
                    help: "Composition frame rate."
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
                    help: "Show the cursor in the screen source."
                )

                opt(
                    "layout",
                    as: String.self,
                    help: "Composition layout: overlay or side-by-side."
                )

                opt(
                    "overlay-source",
                    as: String.self,
                    help: "Overlay source: camera or screen. Defaults to camera."
                )

                opt(
                    "overlay-width",
                    as: Double.self,
                    help: "Overlay width as canvas ratio. Defaults to 0.24."
                )

                opt(
                    "overlay-x",
                    as: String.self,
                    help: "Overlay horizontal placement: left, center, right."
                )

                opt(
                    "overlay-y",
                    as: String.self,
                    help: "Overlay vertical placement: top, middle, bottom."
                )

                opt(
                    "overlay-margin",
                    as: Int.self,
                    help: "Overlay margin in pixels. Defaults to 32."
                )

                opt(
                    "gap",
                    as: Int.self,
                    help: "Gap in pixels for side-by-side layout. Defaults to 24."
                )

                example(
                    "capture compose --camera \"Studio Display Camera\" --audio ext-in --layout overlay --overlay-x right --overlay-y bottom --duration 10 --output ~/Desktop/composed.mov"
                )

                example(
                    "capture compose --camera \"Studio Display Camera\" --audio ext-in --layout side-by-side --duration 10 --output ~/Desktop/side-by-side.mov"
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

                flag(
                    "system-audio",
                    help: "Capture system audio as a separate audio track."
                )

                opt(
                    "audio-layout",
                    as: String.self,
                    help: "Audio layout: separate or mixed. Defaults to separate."
                )

                opt(
                    "mic-gain",
                    as: Double.self,
                    help: "Microphone gain multiplier. Defaults to 1.0."
                )

                opt(
                    "system-gain",
                    as: Double.self,
                    help: "System audio gain multiplier. Defaults to 1.0."
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
                    help: "Video width. Defaults to selected display width. If used without --height, preserves display aspect ratio."
                )

                opt(
                    "height",
                    as: Int.self,
                    help: "Video height. Defaults to selected display height. If used without --width, preserves display aspect ratio."
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

            command("camera") { invocation in
                try await recordCamera(
                    invocation: invocation
                )
            }

            command("compose") { invocation in
                try await recordComposition(
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
        let videoInputs = try await provider.videoInputs()
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
                    title: "Video Inputs",
                    items: [
                        .list(
                            label: "devices",
                            values: labels(
                                for: videoInputs
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
        )

        let height = try invocation.value(
            "height",
            as: Int.self
        )

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

        let provider = MacCaptureDeviceProvider()
        let result = try await ScreenCaptureVideoRecorder().recordVideo(
            configuration: configuration,
            options: options,
            deviceProvider: provider
        )

        writeVideoSummary(
            result: result,
            exportDurationSeconds: nil
        )
    }

    static func recordCamera(
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

        let cameraName = try invocation.value(
            "camera",
            as: String.self
        )

        let audioName = try invocation.value(
            "audio",
            as: String.self
        ) ?? "ext-in"

        let durationSeconds = try invocation.value(
            "duration",
            as: Int.self
        )

        let fps = try invocation.value(
            "fps",
            as: Int.self
        ) ?? 30

        let quality = try videoQuality(
            invocation: invocation
        )

        let bitrate = try invocation.value(
            "bitrate",
            as: Int.self
        )

        let micGain = try invocation.value(
            "mic-gain",
            as: Double.self
        ) ?? 1.0

        let video = try CaptureVideoOptions(
            fps: fps,
            cursor: false,
            quality: quality,
            bitrate: bitrate
        )

        let audio = try CaptureAudioOptions(
            device: .name(
                audioName
            )
        )

        let audioMix = try CaptureAudioMixOptions(
            layout: .separate,
            microphoneGain: micGain,
            systemGain: 1.0
        )

        let configuration = try CaptureCameraConfiguration(
            camera: cameraName.map {
                .name(
                    $0
                )
            } ?? .systemDefault,
            video: video,
            audio: audio,
            audioMix: audioMix,
            container: try container(
                for: output
            ),
            output: output
        )

        let provider = MacCaptureDeviceProvider()
        let resolvedVideo = try await resolvedCameraVideoPreview(
            configuration: configuration,
            provider: provider
        )

        try CaptureCLIStoragePreflight.ensureAvailable(
            output: output,
            video: resolvedVideo,
            durationSeconds: durationSeconds,
            mode: .camera
        )

        let timer = recordingTimer(
            limitSeconds: durationSeconds,
            output: output,
            audioName: audioName,
            systemAudioEnabled: false,
            audioMix: audioMix,
            video: resolvedVideo,
            cameraName: cameraName ?? "default"
        )

        let progressRenderer = CaptureCLIProgressRenderer(
            recordingTimer: timer,
            output: output
        )

        if let durationSeconds {
            let session = CameraCaptureSession(
                configuration: configuration,
                options: try CaptureRecordOptions(
                    durationSeconds: durationSeconds
                ),
                deviceProvider: provider
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            await timer.start()

            do {
                let result = try await session.start()

                await progressRenderer.finishAfterSuccess()

                writeCameraSummary(
                    result: result,
                    exportDurationSeconds: await progressRenderer.exportDurationSeconds()
                )
            } catch {
                await progressRenderer.finishAfterError()
                throw error
            }
        } else {
            let stopSignal = CaptureStopSignal()
            let listener = CaptureCLIStopListener(
                stopSignal: stopSignal
            )

            let session = CameraCaptureSession(
                configuration: configuration,
                deviceProvider: provider
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            listener.start()
            await timer.start()

            do {
                let result = try await session.startUntilStopped(
                    stopSignal: stopSignal
                )

                listener.stop()

                await progressRenderer.finishAfterSuccess()

                writeCameraSummary(
                    result: result,
                    exportDurationSeconds: await progressRenderer.exportDurationSeconds()
                )
            } catch {
                listener.stop()
                await progressRenderer.finishAfterError()
                throw error
            }
        }
    }

    static func recordComposition(
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

        let cameraName = try invocation.value(
            "camera",
            as: String.self
        )

        let audioName = try invocation.value(
            "audio",
            as: String.self
        ) ?? "ext-in"

        let durationSeconds = try invocation.value(
            "duration",
            as: Int.self
        )

        let width = try invocation.value(
            "width",
            as: Int.self
        )

        let height = try invocation.value(
            "height",
            as: Int.self
        )

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

        let systemAudioEnabled = try invocation.flag(
            "system-audio"
        )

        let micGain = try invocation.value(
            "mic-gain",
            as: Double.self
        ) ?? 1.0

        let systemGain = try systemGain(
            invocation: invocation,
            systemAudioEnabled: systemAudioEnabled
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

        let systemAudio = try CaptureSystemAudioOptions(
            enabled: systemAudioEnabled
        )

        let audioMix = try CaptureAudioMixOptions(
            layout: try compositionAudioLayout(
                invocation: invocation
            ),
            microphoneGain: micGain,
            systemGain: systemGain
        )

        let layout = try compositionLayout(
            invocation: invocation
        )

        let configuration = try CaptureCompositionConfiguration(
            camera: cameraName.map {
                .name(
                    $0
                )
            } ?? .systemDefault,
            video: video,
            audio: audio,
            systemAudio: systemAudio,
            audioMix: audioMix,
            layout: layout,
            container: try container(
                for: output
            ),
            output: output
        )

        let provider = MacCaptureDeviceProvider()

        let previewConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: video,
            audio: audio,
            systemAudio: systemAudio,
            audioMix: audioMix,
            container: configuration.container,
            output: output
        )

        let resolvedVideo = try await resolvedVideoPreview(
            configuration: previewConfiguration,
            provider: provider
        )

        try CaptureCLIStoragePreflight.ensureAvailable(
            output: output,
            video: resolvedVideo,
            durationSeconds: durationSeconds,
            mode: .composition
        )

        let layoutDescription = try compositionLayoutDescription(
            invocation: invocation
        )

        let timer = recordingTimer(
            limitSeconds: durationSeconds,
            output: output,
            audioName: audioName,
            systemAudioEnabled: systemAudioEnabled,
            audioMix: audioMix,
            video: resolvedVideo,
            cameraName: cameraName ?? "default",
            layoutDescription: layoutDescription
        )

        let progressRenderer = CaptureCLIProgressRenderer(
            recordingTimer: timer,
            output: output
        )

        if let durationSeconds {
            let session = CaptureCompositionSession(
                configuration: configuration,
                options: try CaptureRecordOptions(
                    durationSeconds: durationSeconds
                ),
                deviceProvider: provider
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            await timer.start()

            do {
                let result = try await session.start()

                await progressRenderer.finishAfterSuccess()

                writeCompositionSummary(
                    result: result,
                    exportDurationSeconds: await progressRenderer.exportDurationSeconds()
                )
            } catch {
                await progressRenderer.finishAfterError()
                throw error
            }
        } else {
            let stopSignal = CaptureStopSignal()
            let listener = CaptureCLIStopListener(
                stopSignal: stopSignal
            )

            let session = CaptureCompositionSession(
                configuration: configuration,
                deviceProvider: provider
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            listener.start()
            await timer.start()

            do {
                let result = try await session.startUntilStopped(
                    stopSignal: stopSignal
                )

                listener.stop()

                await progressRenderer.finishAfterSuccess()

                writeCompositionSummary(
                    result: result,
                    exportDurationSeconds: await progressRenderer.exportDurationSeconds()
                )
            } catch {
                listener.stop()
                await progressRenderer.finishAfterError()
                throw error
            }
        }
    }

    static func recordingTimer(
        limitSeconds: Int?,
        output: URL,
        audioName: String,
        systemAudioEnabled: Bool,
        audioMix: CaptureAudioMixOptions,
        video: CaptureResolvedVideoOptions,
        cameraName: String? = nil,
        layoutDescription: String? = nil
    ) -> TerminalLiveStatusLine {
        TerminalLiveStatusLine(
            limitSeconds: limitSeconds.map(
                TimeInterval.init
            ),
            leadingLines: recordingStartedLines(
                output: output,
                audioName: audioName,
                systemAudioEnabled: systemAudioEnabled,
                audioMix: audioMix,
                video: video,
                limitSeconds: limitSeconds,
                cameraName: cameraName,
                layoutDescription: layoutDescription
            )
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
        )

        let height = try invocation.value(
            "height",
            as: Int.self
        )

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

        let systemAudioEnabled = try invocation.flag(
            "system-audio"
        )

        let micGain = try invocation.value(
            "mic-gain",
            as: Double.self
        ) ?? 1.0

        let systemGain = try systemGain(
            invocation: invocation,
            systemAudioEnabled: systemAudioEnabled
        )

        let audioMix = try CaptureAudioMixOptions(
            layout: audioLayout(
                invocation: invocation
            ),
            microphoneGain: micGain,
            systemGain: systemGain
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

        let audio = try CaptureAudioOptions(
            device: .name(
                audioName
            )
        )

        let systemAudio = try CaptureSystemAudioOptions(
            enabled: systemAudioEnabled
        )

        let configuration = try CaptureConfiguration(
            video: video,
            audio: audio,
            systemAudio: systemAudio,
            audioMix: audioMix,
            container: try container(
                for: output
            ),
            output: output
        )

        let provider = MacCaptureDeviceProvider()
        let resolvedVideo = try await resolvedVideoPreview(
            configuration: configuration,
            provider: provider
        )

        try CaptureCLIStoragePreflight.ensureAvailable(
            output: output,
            video: resolvedVideo,
            durationSeconds: durationSeconds,
            mode: .record
        )

        if let durationSeconds {
            let timer = recordingTimer(
                limitSeconds: durationSeconds,
                output: output,
                audioName: audioName,
                systemAudioEnabled: systemAudioEnabled,
                audioMix: audioMix,
                video: resolvedVideo
            )

            let progressRenderer = CaptureCLIProgressRenderer(
                recordingTimer: timer,
                output: output
            )

            let session = CaptureSession(
                configuration: configuration,
                options: try CaptureRecordOptions(
                    durationSeconds: durationSeconds
                ),
                deviceProvider: provider
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            await timer.start()

            do {
                let result = try await session.start()

                await progressRenderer.finishAfterSuccess()

                writeRecordingSummary(
                    result: result,
                    exportDurationSeconds: await progressRenderer.exportDurationSeconds()
                )
            } catch {
                await progressRenderer.finishAfterError()
                throw error
            }
        } else {
            let stopSignal = CaptureStopSignal()
            let listener = CaptureCLIStopListener(
                stopSignal: stopSignal
            )

            let timer = recordingTimer(
                limitSeconds: nil,
                output: output,
                audioName: audioName,
                systemAudioEnabled: systemAudioEnabled,
                audioMix: audioMix,
                video: resolvedVideo
            )

            let progressRenderer = CaptureCLIProgressRenderer(
                recordingTimer: timer,
                output: output
            )

            let session = CaptureSession(
                configuration: configuration,
                deviceProvider: provider
            ) { progress in
                await progressRenderer.handle(
                    progress
                )
            }

            listener.start()
            await timer.start()

            do {
                let result = try await session.startUntilStopped(
                    stopSignal: stopSignal
                )

                listener.stop()

                await progressRenderer.finishAfterSuccess()

                writeRecordingSummary(
                    result: result,
                    exportDurationSeconds: await progressRenderer.exportDurationSeconds()
                )
            } catch {
                listener.stop()
                await progressRenderer.finishAfterError()
                throw error
            }
        }
    }

    static func resolvedCameraVideoPreview(
        configuration: CaptureCameraConfiguration,
        provider: MacCaptureDeviceProvider
    ) async throws -> CaptureResolvedVideoOptions {
        let resolved = try await CameraCaptureDeviceResolver(
            provider: provider
        ).resolve(
            configuration: configuration
        )

        let size = resolved.videoInput.size ?? CaptureVideoSize(
            width: 1920,
            height: 1080
        )

        let bitrate = configuration.video.bitrate
            ?? configuration.video.quality.recommendedBitrate(
                width: size.width,
                height: size.height,
                fps: configuration.video.fps
            )

        return try CaptureResolvedVideoOptions(
            width: size.width,
            height: size.height,
            fps: configuration.video.fps,
            cursor: false,
            codec: configuration.video.codec,
            quality: configuration.video.quality,
            bitrate: bitrate
        )
    }

    static func compositionLayoutDescription(
        invocation: ParsedInvocation
    ) throws -> String {
        let layout = try invocation.value(
            "layout",
            as: String.self
        ) ?? "overlay"

        switch layout {
        case "overlay":
            let source = try invocation.value(
                "overlay-source",
                as: String.self
            ) ?? CaptureCompositionSource.camera.rawValue

            let width = try invocation.value(
                "overlay-width",
                as: Double.self
            ) ?? 0.24

            let x = try invocation.value(
                "overlay-x",
                as: String.self
            ) ?? CaptureHorizontalPlacement.right.rawValue

            let y = try invocation.value(
                "overlay-y",
                as: String.self
            ) ?? CaptureVerticalPlacement.bottom.rawValue

            return "overlay source=\(source) width=\(String(format: "%.2f", width)) x=\(x) y=\(y)"

        case "side-by-side":
            let gap = try invocation.value(
                "gap",
                as: Int.self
            ) ?? 24

            return "side-by-side gap=\(gap)"

        default:
            return layout
        }
    }

    static func resolvedVideoPreview(
        configuration: CaptureConfiguration,
        provider: any CaptureDeviceProvider
    ) async throws -> CaptureResolvedVideoOptions {
        let resolved = try await CaptureDeviceResolver(
            provider: provider
        ).resolve(
            configuration: configuration
        )

        guard let size = resolved.display.size else {
            throw CaptureError.videoCapture(
                "Could not resolve display size for \(resolved.display.name)."
            )
        }

        return try configuration.video.resolved(
            displaySize: size
        )
    }

    static func audioLayout(
        invocation: ParsedInvocation
    ) throws -> CaptureAudioLayout {
        let value = try invocation.value(
            "audio-layout",
            as: String.self
        ) ?? CaptureAudioLayout.separate.rawValue

        guard let layout = CaptureAudioLayout(
            rawValue: value.lowercased()
        ) else {
            throw CaptureCLIError.invalidAudioLayout(
                value: value,
                allowed: CaptureAudioLayout.allCases.map(\.rawValue)
            )
        }

        return layout
    }

    static func systemGain(
        invocation: ParsedInvocation,
        systemAudioEnabled: Bool
    ) throws -> Double {
        let value = try invocation.value(
            "system-gain",
            as: Double.self
        )

        guard systemAudioEnabled || value == nil || value == 1.0 else {
            throw CaptureError.audioCapture(
                "Cannot use --system-gain without --system-audio. Add --system-audio or remove --system-gain."
            )
        }

        guard systemAudioEnabled else {
            return 1.0
        }

        return value ?? 1.0
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

    static func compositionLayout(
        invocation: ParsedInvocation
    ) throws -> CaptureCompositionLayout {
        let layout = try invocation.value(
            "layout",
            as: String.self
        ) ?? "overlay"

        switch layout {
        case "overlay":
            let overlaySource = try compositionSource(
                value: invocation.value(
                    "overlay-source",
                    as: String.self
                ) ?? "camera"
            )

            let overlayWidth = try invocation.value(
                "overlay-width",
                as: Double.self
            ) ?? 0.24

            let overlayX = try horizontalPlacement(
                value: invocation.value(
                    "overlay-x",
                    as: String.self
                ) ?? "right"
            )

            let overlayY = try verticalPlacement(
                value: invocation.value(
                    "overlay-y",
                    as: String.self
                ) ?? "bottom"
            )

            let overlayMargin = try invocation.value(
                "overlay-margin",
                as: Int.self
            ) ?? 32

            switch overlaySource {
            case .camera:
                return try .screenWithCameraOverlay(
                    cameraWidthRatio: overlayWidth,
                    horizontal: overlayX,
                    vertical: overlayY,
                    margin: overlayMargin
                )

            case .screen:
                return try .cameraWithScreenOverlay(
                    screenWidthRatio: overlayWidth,
                    horizontal: overlayX,
                    vertical: overlayY,
                    margin: overlayMargin
                )
            }

        case "side-by-side":
            return try .screenAndCameraSideBySide(
                gap: try invocation.value(
                    "gap",
                    as: Int.self
                ) ?? 24
            )

        default:
            throw CaptureError.videoCapture(
                "Invalid composition layout: \(layout). Expected overlay or side-by-side."
            )
        }
    }

    static func compositionSource(
        value: String
    ) throws -> CaptureCompositionSource {
        guard let source = CaptureCompositionSource(
            rawValue: value
        ) else {
            throw CaptureError.videoCapture(
                "Invalid composition source: \(value). Expected screen or camera."
            )
        }

        return source
    }

    static func horizontalPlacement(
        value: String
    ) throws -> CaptureHorizontalPlacement {
        guard let placement = CaptureHorizontalPlacement(
            rawValue: value
        ) else {
            throw CaptureError.videoCapture(
                "Invalid horizontal placement: \(value). Expected left, center, or right."
            )
        }

        return placement
    }

    static func verticalPlacement(
        value: String
    ) throws -> CaptureVerticalPlacement {
        guard let placement = CaptureVerticalPlacement(
            rawValue: value
        ) else {
            throw CaptureError.videoCapture(
                "Invalid vertical placement: \(value). Expected top, middle, or bottom."
            )
        }

        return placement
    }

    static func compositionAudioLayout(
        invocation: ParsedInvocation
    ) throws -> CaptureAudioLayout {
        let value = try invocation.value(
            "audio-layout",
            as: String.self
        ) ?? CaptureAudioLayout.separate.rawValue

        guard let layout = CaptureAudioLayout(
            rawValue: value
        ) else {
            throw CaptureError.audioCapture(
                "Invalid audio layout: \(value). Expected separate or mixed."
            )
        }

        return layout
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
