import Arguments
import Capture
import Foundation
import Methods

struct CaptureOutputOptions: Sendable, ArgumentGroup {
    @Opt(
        "output",
        short: "o"
    )
    var path: String?

    @Flag("overwrite")
    var overwrite: Bool

    init() {}

    func url() throws -> URL {
        let path = try path.unwrap(
            message: "Missing --output."
        )

        let output = URL(
            fileURLWithPath: path.expandingTilde()
        )

        try confirmOverwriteIfNeeded(
            output
        )

        return output
    }
}

private extension CaptureOutputOptions {
    func confirmOverwriteIfNeeded(
        _ output: URL
    ) throws {
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(
            atPath: output.path,
            isDirectory: &isDirectory
        ) else {
            return
        }

        guard !isDirectory.boolValue else {
            throw CaptureCLIError.outputPathIsDirectory(
                output
            )
        }

        guard !overwrite else {
            return
        }

        guard askOverwrite(
            output
        ) else {
            throw CaptureCLIError.overwriteDeclined(
                output
            )
        }
    }

    func askOverwrite(
        _ output: URL
    ) -> Bool {
        writePrompt(
            """
            capture: output file already exists:
              \(output.path)
            Overwrite? [y/N] 
            """
        )

        let answer = readLine()?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        return answer == "y" || answer == "yes"
    }

    func writePrompt(
        _ value: String
    ) {
        FileHandle.standardError.write(
            Data(
                value.utf8
            )
        )
    }
}

struct CaptureWorkspaceCLIOptions: Sendable, ArgumentGroup {
    @Opt("workdir")
    var path: String?

    init() {}

    func workspace() -> CaptureWorkspaceOptions {
        if let path = trimmedOrNil(
            path
        ) {
            return CaptureWorkspaceOptions(
                root: URL(
                    fileURLWithPath: path.expandingTilde(),
                    isDirectory: true
                )
            )
        }

        if let path = trimmedOrNil(
            ProcessInfo.processInfo.environment["CAPTURE_WORKDIR"]
        ) {
            return CaptureWorkspaceOptions(
                root: URL(
                    fileURLWithPath: path.expandingTilde(),
                    isDirectory: true
                )
            )
        }

        return .standard
    }
}

struct CaptureDurationOptions: Sendable, ArgumentGroup {
    @Opt(
        "duration",
        short: "d"
    )
    var seconds: Int?

    init() {}

    func fixed(
        default defaultSeconds: Int
    ) throws -> Int {
        try CaptureRecordOptions(
            durationSeconds: seconds ?? defaultSeconds
        ).durationSeconds
    }

    func optional() throws -> Int? {
        guard let seconds else {
            return nil
        }

        return try CaptureRecordOptions(
            durationSeconds: seconds
        ).durationSeconds
    }
}

struct CaptureVideoCLIOptions: Sendable, ArgumentGroup {
    @Opt("width")
    var width: Int?

    @Opt("height")
    var height: Int?

    @Opt("fps")
    var fps: Int?

    @Opt("quality")
    var quality: String?

    @Opt("bitrate")
    var bitrate: Int?

    @Flag(
        "cursor",
        default: true
    )
    var cursor: Bool

    init() {}

    func video(
        defaultFPS: Int,
        defaultCursor: Bool? = nil
    ) throws -> CaptureVideoOptions {
        try CaptureVideoOptions(
            width: width,
            height: height,
            fps: fps ?? defaultFPS,
            cursor: defaultCursor ?? cursor,
            quality: try resolvedQuality(),
            bitrate: bitrate
        )
    }
}

struct CaptureMicrophoneOptions: Sendable, ArgumentGroup {
    @Opt(
        "audio",
        short: "a"
    )
    var name: String?

    init() {}

    func audio(
        sampleRate: Int = 48_000,
        channel: Int = 1,
        codec: CaptureAudioCodec = .pcm
    ) throws -> CaptureAudioOptions {
        try CaptureAudioOptions(
            device: .name(
                trimmedOrNil(
                    name
                ) ?? "ext-in"
            ),
            sampleRate: sampleRate,
            channel: channel,
            codec: codec
        )
    }
}

struct CaptureMicrophoneGainOptions: Sendable, ArgumentGroup {
    @Opt(
        "mic-gain",
        default: 1.0
    )
    var micGain: Double

    init() {}

    func audioMix() throws -> CaptureAudioMixOptions {
        try CaptureAudioMixOptions(
            layout: .separate,
            microphoneGain: micGain,
            systemGain: 1.0
        )
    }
}

struct CaptureSystemAudioCLIOptions: Sendable, ArgumentGroup {
    @Flag("system-audio")
    var enabled: Bool

    @Opt("audio-layout")
    var layout: String?

    @Opt(
        "mic-gain",
        default: 1.0
    )
    var micGain: Double

    @Opt(
        "system-gain",
        default: 1.0
    )
    var systemGain: Double

    init() {}

    func systemAudio() throws -> CaptureSystemAudioOptions {
        try CaptureSystemAudioOptions(
            enabled: enabled
        )
    }

    func audioMix() throws -> CaptureAudioMixOptions {
        guard enabled || systemGain == 1.0 else {
            throw CaptureError.audioCapture(
                "Cannot use --system-gain without --system-audio. Add --system-audio or remove --system-gain."
            )
        }

        return try CaptureAudioMixOptions(
            layout: try resolvedLayout(),
            microphoneGain: micGain,
            systemGain: enabled ? systemGain : 1.0
        )
    }
}

struct CaptureCameraCLIOptions: Sendable, ArgumentGroup {
    @Opt(
        "camera",
        short: "c"
    )
    var name: String?

    init() {}

    var camera: CaptureVideoInput {
        trimmedOrNil(
            name
        ).map {
            .name(
                $0
            )
        } ?? .systemDefault
    }

    var displayName: String {
        trimmedOrNil(
            name
        ) ?? "default"
    }
}

struct CaptureCompositionLayoutCLIOptions: Sendable, ArgumentGroup {
    @Opt("layout")
    var layout: String?

    @Opt("overlay-source")
    var overlaySource: String?

    @Opt(
        "overlay-width",
        default: 0.24
    )
    var overlayWidth: Double

    @Opt("overlay-x")
    var overlayX: String?

    @Opt("overlay-y")
    var overlayY: String?

    @Opt(
        "overlay-margin",
        default: 32
    )
    var overlayMargin: Int

    @Opt(
        "gap",
        default: 24
    )
    var gap: Int

    init() {}

    func compositionLayout() throws -> CaptureCompositionLayout {
        switch trimmedOrNil(layout) ?? "overlay" {
        case "overlay":
            let source = try compositionSource(
                trimmedOrNil(
                    overlaySource
                ) ?? "camera"
            )

            let horizontal = try horizontalPlacement(
                trimmedOrNil(
                    overlayX
                ) ?? "right"
            )

            let vertical = try verticalPlacement(
                trimmedOrNil(
                    overlayY
                ) ?? "bottom"
            )

            switch source {
            case .camera:
                return try .screenWithCameraOverlay(
                    cameraWidthRatio: overlayWidth,
                    horizontal: horizontal,
                    vertical: vertical,
                    margin: overlayMargin
                )

            case .screen:
                return try .cameraWithScreenOverlay(
                    screenWidthRatio: overlayWidth,
                    horizontal: horizontal,
                    vertical: vertical,
                    margin: overlayMargin
                )
            }

        case "side-by-side":
            return try .screenAndCameraSideBySide(
                gap: gap
            )

        case let value:
            throw CaptureError.videoCapture(
                "Invalid composition layout: \(value). Expected overlay or side-by-side."
            )
        }
    }

    func description() throws -> String {
        switch trimmedOrNil(layout) ?? "overlay" {
        case "overlay":
            let source = trimmedOrNil(
                overlaySource
            ) ?? "camera"

            let x = trimmedOrNil(
                overlayX
            ) ?? "right"

            let y = trimmedOrNil(
                overlayY
            ) ?? "bottom"

            return "overlay source=\(source) width=\(String(format: "%.2f", overlayWidth)) x=\(x) y=\(y)"

        case "side-by-side":
            return "side-by-side gap=\(gap)"

        case let value:
            return value
        }
    }
}

extension CaptureVideoCLIOptions {
    func resolvedQuality() throws -> CaptureVideoQuality {
        let value = trimmedOrNil(
            quality
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
}

extension CaptureSystemAudioCLIOptions {
    func resolvedLayout() throws -> CaptureAudioLayout {
        let value = trimmedOrNil(
            layout
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
}

func compositionSource(
    _ value: String
) throws -> CaptureCompositionSource {
    guard let source = CaptureCompositionSource(
        rawValue: value.lowercased()
    ) else {
        throw CaptureError.videoCapture(
            "Invalid composition source: \(value). Expected screen or camera."
        )
    }

    return source
}

func horizontalPlacement(
    _ value: String
) throws -> CaptureHorizontalPlacement {
    guard let placement = CaptureHorizontalPlacement(
        rawValue: value.lowercased()
    ) else {
        throw CaptureError.videoCapture(
            "Invalid horizontal placement: \(value). Expected left, center, or right."
        )
    }

    return placement
}

func verticalPlacement(
    _ value: String
) throws -> CaptureVerticalPlacement {
    guard let placement = CaptureVerticalPlacement(
        rawValue: value.lowercased()
    ) else {
        throw CaptureError.videoCapture(
            "Invalid vertical placement: \(value). Expected top, middle, or bottom."
        )
    }

    return placement
}

// func trimmedOrNil(
//     _ value: String?
// ) -> String? {
//     guard let value else {
//         return nil
//     }

//     let trimmed = value.trimmingCharacters(
//         in: .whitespacesAndNewlines
//     )

//     return trimmed.isEmpty ? nil : trimmed
// }
