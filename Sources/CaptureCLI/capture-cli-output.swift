import Capture
import Foundation
import Terminal

extension CaptureCLI {
    static var captureOutputLayout: TerminalBlockLayout {
        TerminalBlockLayout(
            fieldIndent: 2,
            labelWidth: .minimum(16),
            labelValueSpacing: 2,
            blankLinesAfter: 1
        )
    }

    static func recordingStartedLines(
        output: URL,
        audioName: String?,
        systemAudioEnabled: Bool,
        audioMix: CaptureAudioMixOptions,
        video: CaptureResolvedVideoOptions,
        limitSeconds: Int?,
        cameraName: String? = nil,
        layoutDescription: String? = nil
    ) -> [String] {
        let mode: String
        let stop: String

        if let limitSeconds {
            mode = "fixed duration \(TerminalDurationFormatter.format(TimeInterval(limitSeconds)))"
            stop = "waits for duration limit"
        } else {
            mode = "live"
            stop = "press q + Return, Ctrl-C, or send SIGTERM"
        }

        var fields: [TerminalField] = [
            .init(
                "output",
                output.path
            ),
        ]

        if let cameraName {
            fields.append(
                .init(
                    "camera",
                    cameraName
                )
            )
        }

        if let layoutDescription {
            fields.append(
                .init(
                    "layout",
                    layoutDescription
                )
            )
        }

        if let audioName {
            fields.append(
                .init(
                    "mic audio",
                    audioName
                )
            )
        }

        fields.append(
            .init(
                "system audio",
                systemAudioEnabled ? "enabled" : "disabled"
            )
        )

        fields.append(
            contentsOf: [
                .init(
                    "audio layout",
                    audioMix.requiresAudioRendering
                        ? CaptureAudioLayout.mixed.rawValue
                        : audioMix.layout.rawValue
                ),
                .init(
                    "mic gain",
                    gainDescription(
                        audioMix.microphoneGain
                    )
                ),
                .init(
                    "system gain",
                    gainDescription(
                        audioMix.systemGain
                    )
                ),
            ]
        )

        fields.append(
            contentsOf: videoConfigurationFields(
                video
            )
        )

        fields.append(
            contentsOf: [
                .init(
                    "mode",
                    mode
                ),
                .init(
                    "stop",
                    stop
                ),
            ]
        )

        return renderedLines(
            TerminalBlock(
                title: "capture: recording",
                fields: fields,
                theme: .agentic,
                layout: captureOutputLayout
            )
        )
    }

    static func writeVideoSummary(
        result: CaptureVideoRecordingResult,
        exportDurationSeconds: TimeInterval? = nil
    ) {
        var fields = videoSummaryFields(
            output: result.output,
            durationSeconds: result.durationSeconds,
            video: result.video,
            diagnostics: result.diagnostics
        )

        fields.append(
            contentsOf: outputMetadataFields(
                output: result.output,
                exportDurationSeconds: exportDurationSeconds
            )
        )

        writeBlock(
            TerminalBlock(
                title: "capture: wrote video",
                fields: fields,
                theme: .agentic,
                layout: captureOutputLayout
            )
        )
    }

    static func writeCameraSummary(
        result: CaptureCameraRecordingResult,
        exportDurationSeconds: TimeInterval? = nil
    ) {
        var fields = cameraSummaryFields(
            result: result
        )

        fields.append(
            contentsOf: outputMetadataFields(
                output: result.output,
                exportDurationSeconds: exportDurationSeconds
            )
        )

        writeBlock(
            TerminalBlock(
                title: "capture: wrote camera recording",
                fields: fields,
                theme: .agentic,
                layout: captureOutputLayout
            )
        )
    }

    static func writeCompositionSummary(
        result: CaptureCompositionRecordingResult,
        exportDurationSeconds: TimeInterval? = nil
    ) {
        var fields = compositionSummaryFields(
            result: result
        )

        fields.append(
            contentsOf: outputMetadataFields(
                output: result.output,
                exportDurationSeconds: exportDurationSeconds
            )
        )

        writeBlock(
            TerminalBlock(
                title: "capture: wrote composed recording",
                fields: fields,
                theme: .agentic,
                layout: captureOutputLayout
            )
        )
    }

    static func writeRecordingSummary(
        result: CaptureRecordingResult,
        exportDurationSeconds: TimeInterval? = nil
    ) {
        var fields = videoSummaryFields(
            output: result.output,
            durationSeconds: result.durationSeconds,
            video: result.video,
            diagnostics: result.videoDiagnostics
        )

        fields.insert(
            .init(
                "audio tracks",
                "\(result.audioTrackCount)"
            ),
            at: 3
        )

        fields.insert(
            .init(
                "audio layout",
                result.audioLayout.rawValue
            ),
            at: 4
        )

        fields.insert(
            .init(
                "mic gain",
                gainDescription(
                    result.microphoneGain
                )
            ),
            at: 5
        )

        fields.insert(
            .init(
                "system gain",
                gainDescription(
                    result.systemGain
                )
            ),
            at: 6
        )

        fields.insert(
            .init(
                "audio offsets",
                audioOffsetDescription(
                    result
                )
            ),
            at: 7
        )

        if let systemAudioSampleBufferCount = result.systemAudioSampleBufferCount {
            fields.insert(
                .init(
                    "system samples",
                    "\(systemAudioSampleBufferCount)"
                ),
                at: 8
            )
        }

        fields.append(
            contentsOf: outputMetadataFields(
                output: result.output,
                exportDurationSeconds: exportDurationSeconds
            )
        )

        writeBlock(
            TerminalBlock(
                title: "capture: wrote recording",
                fields: fields,
                theme: .agentic,
                layout: captureOutputLayout
            )
        )
    }

    static func videoDescription(
        _ video: CaptureResolvedVideoOptions
    ) -> String {
        "\(video.width)x\(video.height) @ \(video.fps)fps quality=\(video.quality.rawValue) bitrate=\(bitrateDescription(video.bitrate))"
    }
}

private extension CaptureCLI {
    static func videoConfigurationFields(
        _ video: CaptureResolvedVideoOptions
    ) -> [TerminalField] {
        [
            .init(
                "resolution",
                "\(video.width)x\(video.height)"
            ),
            .init(
                "fps",
                "\(video.fps)"
            ),
            .init(
                "quality",
                video.quality.rawValue
            ),
            .init(
                "bitrate",
                bitrateDescription(
                    video.bitrate
                )
            ),
        ]
    }

    static func videoSummaryFields(
        output: URL,
        durationSeconds: Int,
        video: CaptureResolvedVideoOptions,
        diagnostics: CaptureVideoRecordingDiagnostics
    ) -> [TerminalField] {
        [
            .init(
                "output",
                output.path
            ),
            .init(
                "duration",
                TerminalDurationFormatter.format(
                    diagnostics.recordedSeconds
                )
            ),
            .init(
                "resolution",
                "\(video.width)x\(video.height)"
            ),
            .init(
                "quality",
                video.quality.rawValue
            ),
            .init(
                "bitrate",
                bitrateDescription(
                    video.bitrate
                )
            ),
            .init(
                "requested fps",
                "\(diagnostics.requestedFramesPerSecond)"
            ),
            .init(
                "effective fps",
                framesPerSecondDescription(
                    diagnostics.effectiveFramesPerSecond
                )
            ),
            .init(
                "source fps",
                framesPerSecondDescription(
                    diagnostics.completeSourceFramesPerSecond
                )
            ),
            .init(
                "frames",
                "\(diagnostics.finishedFrameCount) finished / \(diagnostics.requestedFrameBudget) requested budget"
            ),
            .init(
                "missed budget",
                "\(diagnostics.missedFrameBudget)"
            ),
            .init(
                "source samples",
                sourceSampleDescription(
                    diagnostics
                )
            ),
            .init(
                "frame statuses",
                frameStatusDescription(
                    diagnostics
                )
            ),
            .init(
                "writer busy",
                "\(diagnostics.writerNotReadyFrameCount) frames"
            ),
            .init(
                "append skips",
                appendSkipDescription(
                    diagnostics
                )
            ),
            .init(
                "status",
                qualityStatusDescription(
                    diagnostics
                )
            ),
        ]
    }

    static func cameraSummaryFields(
        result: CaptureCameraRecordingResult
    ) -> [TerminalField] {
        [
            .init(
                "output",
                result.output.path
            ),
            .init(
                "camera",
                result.camera.name
            ),
            .init(
                "mic audio",
                result.audioInput.name
            ),
            .init(
                "duration",
                TerminalDurationFormatter.format(
                    TimeInterval(
                        result.durationSeconds
                    )
                )
            ),
            .init(
                "resolution",
                "\(result.video.width)x\(result.video.height)"
            ),
            .init(
                "fps",
                "\(result.video.fps)"
            ),
            .init(
                "quality",
                result.video.quality.rawValue
            ),
            .init(
                "bitrate",
                bitrateDescription(
                    result.video.bitrate
                )
            ),
            .init(
                "frames",
                "\(result.videoFrameCount)"
            ),
            .init(
                "audio tracks",
                "\(result.audioTrackCount)"
            ),
            .init(
                "mic gain",
                gainDescription(
                    result.microphoneGain
                )
            ),
            .init(
                "audio offsets",
                "mic=\(syncOffsetDescription(result.microphoneStartOffsetSeconds))"
            ),
        ]
    }

    static func compositionSummaryFields(
        result: CaptureCompositionRecordingResult
    ) -> [TerminalField] {
        [
            .init(
                "output",
                result.output.path
            ),
            .init(
                "duration",
                TerminalDurationFormatter.format(
                    TimeInterval(
                        result.durationSeconds
                    )
                )
            ),
            .init(
                "resolution",
                "\(result.video.width)x\(result.video.height)"
            ),
            .init(
                "fps",
                "\(result.video.fps)"
            ),
            .init(
                "quality",
                result.video.quality.rawValue
            ),
            .init(
                "bitrate",
                bitrateDescription(
                    result.video.bitrate
                )
            ),
            .init(
                "screen frames",
                "\(result.screenFrameCount)"
            ),
            .init(
                "camera frames",
                "\(result.cameraFrameCount)"
            ),
            .init(
                "audio tracks",
                "\(result.audioTrackCount)"
            ),
            .init(
                "audio layout",
                result.audioLayout.rawValue
            ),
            .init(
                "mic gain",
                gainDescription(
                    result.microphoneGain
                )
            ),
            .init(
                "system gain",
                gainDescription(
                    result.systemGain
                )
            ),
            .init(
                "audio offsets",
                compositionAudioOffsetDescription(
                    result
                )
            ),
        ]
    }

    static func compositionAudioOffsetDescription(
        _ result: CaptureCompositionRecordingResult
    ) -> String {
        let systemOffset = result.systemAudioStartOffsetSeconds
            .map(syncOffsetDescription)
            ?? "none"

        return "mic=\(syncOffsetDescription(result.microphoneStartOffsetSeconds)) system=\(systemOffset)"
    }

    static func sourceSampleDescription(
        _ diagnostics: CaptureVideoRecordingDiagnostics
    ) -> String {
        "\(diagnostics.screenSampleCount) screen / \(diagnostics.readySampleCount) ready / \(diagnostics.totalSampleCount) total"
    }

    static func frameStatusDescription(
        _ diagnostics: CaptureVideoRecordingDiagnostics
    ) -> String {
        var parts = [
            "complete=\(diagnostics.completeFrameStatusCount)",
            "idle=\(diagnostics.frameStatusRawValueCounts[1] ?? 0)",
            "incomplete=\(diagnostics.incompleteFrameStatusCount)",
            "missing=\(diagnostics.missingFrameStatusCount)",
        ]

        let rawValues = diagnostics.frameStatusRawValueCounts
            .sorted {
                $0.key < $1.key
            }
            .map {
                "\(frameStatusName(rawValue: $0.key)):\($0.value)"
            }
            .joined(
                separator: ", "
            )

        if !rawValues.isEmpty {
            parts.append(
                "raw={\(rawValues)}"
            )
        }

        return parts.joined(
            separator: " "
        )
    }

    static func frameStatusName(
        rawValue: Int
    ) -> String {
        switch rawValue {
        case 1:
            return "idle"

        default:
            return "\(rawValue)"
        }
    }

    static func appendSkipDescription(
        _ diagnostics: CaptureVideoRecordingDiagnostics
    ) -> String {
        guard diagnostics.appendSkipCount > 0 else {
            return "none"
        }

        return [
            "total=\(diagnostics.appendSkipCount)",
            "writerNotReady=\(diagnostics.writerNotReadyFrameCount)",
            "missingPixelBuffer=\(diagnostics.missingPixelBufferFrameCount)",
            "invalidPTS=\(diagnostics.invalidPresentationTimeFrameCount)",
            "appendFailed=\(diagnostics.appendFailedFrameCount)",
            "afterFinished=\(diagnostics.skippedAfterFinishedFrameCount)",
            "afterFailure=\(diagnostics.skippedAfterFailureFrameCount)",
        ].joined(
            separator: " "
        )
    }

    static func qualityStatusDescription(
        _ diagnostics: CaptureVideoRecordingDiagnostics
    ) -> String {
        let requested = Double(
            diagnostics.requestedFramesPerSecond
        )

        guard requested > 0 else {
            return "unknown"
        }

        let ratio = diagnostics.effectiveFramesPerSecond / requested
        let idleCount = diagnostics.frameStatusRawValueCounts[
            1
        ] ?? 0
        let nonIdleIncompleteCount = max(
            0,
            diagnostics.incompleteSourceSampleCount - idleCount
        )

        if ratio >= 0.95,
           diagnostics.writerNotReadyFrameCount == 0,
           nonIdleIncompleteCount == 0 {
            return "ok"
        }

        if diagnostics.writerNotReadyFrameCount > 0 {
            return "writer backpressure; lower resolution/fps or bitrate"
        }

        if nonIdleIncompleteCount > 0 {
            return "source delivered non-complete frames; below requested fps"
        }

        if ratio < 0.95 {
            return "source delivered fewer changed frames than requested"
        }

        return "ok"
    }

    static func framesPerSecondDescription(
        _ value: Double
    ) -> String {
        String(
            format: "%.1f",
            value
        )
    }

    static func audioOffsetDescription(
        _ result: CaptureRecordingResult
    ) -> String {
        let systemOffset = result.systemAudioStartOffsetSeconds
            .map(syncOffsetDescription)
            ?? "none"

        return "mic=\(syncOffsetDescription(result.microphoneStartOffsetSeconds)) system=\(systemOffset)"
    }

    static func syncOffsetDescription(
        _ value: TimeInterval
    ) -> String {
        String(
            format: "%+.3fs",
            value
        )
    }

    static func gainDescription(
        _ value: Double
    ) -> String {
        String(
            format: "%.2fx",
            value
        )
    }

    static func bitrateDescription(
        _ bitrate: Int
    ) -> String {
        if bitrate >= 1_000_000 {
            return String(
                format: "%.1f Mbps",
                Double(bitrate) / 1_000_000.0
            )
        }

        if bitrate >= 1_000 {
            return String(
                format: "%.1f Kbps",
                Double(bitrate) / 1_000.0
            )
        }

        return "\(bitrate) bps"
    }

    static func outputMetadataFields(
        output: URL,
        exportDurationSeconds: TimeInterval?
    ) -> [TerminalField] {
        let byteCount = outputByteCount(
            output
        )

        var fields: [TerminalField] = []

        if let exportDurationSeconds {
            fields.append(
                .init(
                    "export time",
                    TerminalDurationFormatter.format(
                        exportDurationSeconds
                    )
                )
            )
        }

        fields.append(
            .init(
                "file size",
                fileSizeDescription(
                    byteCount
                )
            )
        )

        fields.append(
            .init(
                "bytes written",
                byteCountDescription(
                    byteCount
                )
            )
        )

        return fields
    }

    static func outputByteCount(
        _ output: URL
    ) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(
            atPath: output.path
        ),
        let size = attributes[.size] as? NSNumber else {
            return nil
        }

        return size.int64Value
    }

    static func fileSizeDescription(
        _ byteCount: Int64?
    ) -> String {
        guard let byteCount else {
            return "unknown"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [
            .useKB,
            .useMB,
            .useGB,
        ]
        formatter.countStyle = .file
        formatter.includesActualByteCount = false

        return formatter.string(
            fromByteCount: byteCount
        )
    }

    static func byteCountDescription(
        _ byteCount: Int64?
    ) -> String {
        guard let byteCount else {
            return "unknown"
        }

        return "\(byteCount)"
    }

    static func renderedLines(
        _ block: TerminalBlock
    ) -> [String] {
        var lines = block.render(
            stream: .standardError
        )
        .split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map(
            String.init
        )

        while lines.last == "" {
            lines.removeLast()
        }

        return lines
    }

    static func writeBlock(
        _ block: TerminalBlock
    ) {
        fputs(
            block.render(
                stream: .standardError
            ),
            stderr
        )
    }
}
