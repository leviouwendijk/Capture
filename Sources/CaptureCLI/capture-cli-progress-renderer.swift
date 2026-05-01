import Foundation
import Capture
import Terminal

internal actor CaptureCLIProgressRenderer {
    private let recordingTimer: TerminalLiveStatusLine
    private let output: URL

    private var recordingStartedAt: Date?
    private var healthSnapshot: CaptureRecordingHealthSnapshot?
    private var recordingTimerStopped = false
    private var exportStatusLine: TerminalLiveStatusLine?
    private var exportStartedAt: Date?
    private var exportFinishedAt: Date?

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
        case .recordingStarted(let startedAt):
            recordingStartedAt = startedAt

        case .recordingHealth(let snapshot):
            healthSnapshot = snapshot

        case .recordingStopped(let durationSeconds):
            await stopRecordingTimer(
                durationSeconds: durationSeconds
            )

        case .exportStarted(let mode):
            exportStartedAt = Date()
            exportFinishedAt = nil

            await startExportStatusLineIfNeeded(
                mode: mode
            )

        case .exportFinished(let mode):
            exportFinishedAt = Date()

            await stopExportStatusLineIfNeeded(
                mode: mode,
                finalLine: "export: exported \(output.path)"
            )
        }
    }

    func finishAfterSuccess() async {
        if !recordingTimerStopped {
            await stopRecordingTimer(
                durationSeconds: fallbackDurationSeconds()
            )
        }

        if let exportStatusLine {
            await exportStatusLine.stop(
                finalLine: "export: exported \(output.path)"
            )
            self.exportStatusLine = nil
        }

        writeHealthWarnings()
    }

    func finishAfterError() async {
        if !recordingTimerStopped {
            await recordingTimer.stop(
                finalLine: "recording: failed"
            )
            recordingTimerStopped = true
        }

        if let exportStatusLine {
            await exportStatusLine.stop(
                finalLine: "export: failed"
            )
            self.exportStatusLine = nil
        }

        writeHealthWarnings()
    }

    func exportDurationSeconds() -> TimeInterval? {
        guard let exportStartedAt,
              let exportFinishedAt else {
            return nil
        }

        let duration = exportFinishedAt.timeIntervalSince(
            exportStartedAt
        )

        guard duration.isFinite,
              duration >= 0 else {
            return nil
        }

        return duration
    }
}

private extension CaptureCLIProgressRenderer {
    func fallbackDurationSeconds() -> TimeInterval {
        guard let recordingStartedAt else {
            return 0
        }

        let duration = Date().timeIntervalSince(
            recordingStartedAt
        )

        guard duration.isFinite,
              duration >= 0 else {
            return 0
        }

        return duration
    }

    func stopRecordingTimer(
        durationSeconds: TimeInterval
    ) async {
        guard !recordingTimerStopped else {
            return
        }

        recordingTimerStopped = true

        await recordingTimer.stop(
            finalLine: recordingStoppedLine(
                durationSeconds: durationSeconds
            )
        )

        writeHealthWarnings()
    }

    func recordingStoppedLine(
        durationSeconds: TimeInterval
    ) -> String {
        let base = "recording: stopped at \(TerminalDurationFormatter.format(durationSeconds))"

        guard let healthSnapshot else {
            return base
        }

        let description = healthSnapshot.briefDescription

        guard !description.isEmpty else {
            return base
        }

        return "\(base)    \(description)"
    }

    func writeHealthWarnings() {
        guard let healthSnapshot else {
            return
        }

        for warning in healthSnapshot.warningDescriptions {
            fputs(
                "warning: \(warning)\n",
                stderr
            )
        }
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
            "-",
            "\\",
            "|",
            "/",
        ]

        let statusLine = TerminalLiveStatusLine(
            leadingLines: [
                "export: rendering",
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
