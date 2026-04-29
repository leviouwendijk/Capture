import Foundation
import Capture
import Terminal

internal actor CaptureCLIProgressRenderer {
    private let recordingTimer: TerminalLiveStatusLine
    private let output: URL
    private var recordingTimerStopped = false
    private var exportStatusLine: TerminalLiveStatusLine?

    init(
        recordingTimer: TerminalLiveStatusLine,
        output: URL
    ) {
        self.recordingTimer = recordingTimer
        self.output = output
    }

    func handle(
        _ progress: CaptureSessionProgress
    ) async {
        switch progress {
        case .recordingStopped(let durationSeconds):
            await stopRecordingTimer(
                durationSeconds: durationSeconds
            )

        case .exportStarted(let mode):
            await startExportStatusLineIfNeeded(
                mode: mode
            )

        case .exportFinished(let mode):
            await stopExportStatusLineIfNeeded(
                mode: mode,
                finalLine: "export: exported \(output.path)"
            )
        }
    }

    func finishAfterSuccess() async {
        if !recordingTimerStopped {
            await stopRecordingTimer(
                durationSeconds: 0
            )
        }

        if let exportStatusLine {
            await exportStatusLine.stop(
                finalLine: "export: exported \(output.path)"
            )
            self.exportStatusLine = nil
        }
    }

    func finishAfterError() async {
        if !recordingTimerStopped {
            await recordingTimer.stop()
            recordingTimerStopped = true
        }

        if let exportStatusLine {
            await exportStatusLine.stop(
                finalLine: "export: failed"
            )
            self.exportStatusLine = nil
        }
    }
}

private extension CaptureCLIProgressRenderer {
    func stopRecordingTimer(
        durationSeconds: TimeInterval
    ) async {
        guard !recordingTimerStopped else {
            return
        }

        recordingTimerStopped = true

        await recordingTimer.stop(
            finalLine: "recording: stopped at \(TerminalDurationFormatter.format(durationSeconds))"
        )
    }

    func startExportStatusLineIfNeeded(
        mode: CaptureExportMode
    ) async {
        guard mode == .rendering else {
            return
        }

        guard exportStatusLine == nil else {
            return
        }

        let frames = [
            "⠋",
            "⠙",
            "⠹",
            "⠸",
            "⠼",
            "⠴",
            "⠦",
            "⠧",
            "⠇",
            "⠏",
        ]

        let statusLine = TerminalLiveStatusLine(
            leadingLines: [
                "export: rendering audio",
            ]
        ) { frame in
            let index = Int(
                (
                    frame.elapsedSeconds * 10
                ).rounded(
                    .down
                )
            ) % frames.count

            return "\(frames[index]) export: rendering \(frame.elapsedText)"
        }

        exportStatusLine = statusLine

        await statusLine.start()
    }

    func stopExportStatusLineIfNeeded(
        mode: CaptureExportMode,
        finalLine: String
    ) async {
        guard mode == .rendering else {
            return
        }

        guard let exportStatusLine else {
            return
        }

        await exportStatusLine.stop(
            finalLine: finalLine
        )

        self.exportStatusLine = nil
    }
}
