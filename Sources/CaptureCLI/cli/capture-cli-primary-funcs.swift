import Foundation
import Capture
import Terminal
import Darwin

internal extension CaptureCLI {
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

internal extension CaptureCLI {
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
}

internal extension CaptureCLI {
    static func writeError(
        _ error: Error
    ) {
        if let partialError = error as? CapturePartialRecordingError {
            CaptureCLINotifier.standard.partialRecordingRetained(
                partialError
            )

            fputs(
                partialRecordingErrorMessage(
                    partialError
                ),
                stderr
            )

            return
        }

        CaptureCLINotifier.standard.recordingFailed(
            error
        )

        fputs(
            "capture: \(error.localizedDescription)\n",
            stderr
        )
    }
    // static func writeError(
    //     _ error: Error
    // ) async {
    //     if let partialError = error as? CapturePartialRecordingError {
    //         await CaptureCLINotifier.standard.partialRecordingRetained(
    //             partialError
    //         )

    //         fputs(
    //             partialRecordingErrorMessage(
    //                 partialError
    //             ),
    //             stderr
    //         )

    //         return
    //     }

    //     await CaptureCLINotifier.standard.recordingFailed(
    //         error
    //     )

    //     fputs(
    //         "capture: \(error.localizedDescription)\n",
    //         stderr
    //     )
    // }

    static func partialRecordingErrorMessage(
        _ error: CapturePartialRecordingError
    ) -> String {
        var lines = [
            "capture: \(error.localizedDescription)",
            "cause: \(error.underlyingErrorDescription)",
            "working directory: \(error.workingDirectory.path)",
        ]

        if error.retainedFiles.isEmpty {
            lines.append(
                "files: none"
            )
        } else {
            lines.append(
                "files:"
            )

            for file in error.retainedFiles {
                let path = relativePath(
                    file,
                    inside: error.workingDirectory
                )

                lines.append(
                    "  - \(path)"
                )
            }
        }

        return lines.joined(
            separator: "\n"
        ) + "\n"
    }

    static func relativePath(
        _ url: URL,
        inside directory: URL
    ) -> String {
        let directoryPath = directory.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        let prefix = directoryPath + "/"

        guard filePath.hasPrefix(
            prefix
        ) else {
            return filePath
        }

        return String(
            filePath.dropFirst(
                prefix.count
            )
        )
    }
}
