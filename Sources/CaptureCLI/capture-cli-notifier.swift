import Foundation
import Capture

internal struct CaptureCLINotifier: Sendable {
    internal static let standard = CaptureCLINotifier()

    internal func partialRecordingRetained(
        _ error: CapturePartialRecordingError
    ) {
        notify(
            .partialRecordingRetained(
                error
            )
        )
    }

    internal func recordingFailed(
        _ error: Error
    ) {
        notify(
            .recordingFailed(
                error
            )
        )
    }
}

private extension CaptureCLINotifier {
    func notify(
        _ notification: CaptureUserNotification
    ) {
        guard let executableURL = executableURL() else {
            return
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "-e",
            notification.appleScriptDisplayNotificationSource,
        ]

        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
        } catch {
            return
        }
    }

    func executableURL() -> URL? {
        let candidates = [
            "/usr/bin/osascript",
            "/bin/osascript",
        ]

        return candidates
            .map {
                URL(
                    fileURLWithPath: $0
                )
            }
            .first {
                FileManager.default.isExecutableFile(
                    atPath: $0.path
                )
            }
    }
}
