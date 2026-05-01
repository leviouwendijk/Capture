import Capture
import Foundation
import TestFlows

extension CaptureFlowSuite {
    static var notificationFlow: TestFlow {
        TestFlow(
            "notification",
            tags: [
                "notification",
                "error",
                "cli",
            ]
        ) {
            Step("partial recording notification is deterministic") {
                let error = CapturePartialRecordingError(
                    workingDirectory: URL(
                        fileURLWithPath: "/tmp/capture-partial-test",
                        isDirectory: true
                    ),
                    retainedFiles: [
                        URL(
                            fileURLWithPath: "/tmp/capture-partial-test/video.mov"
                        ),
                        URL(
                            fileURLWithPath: "/tmp/capture-partial-test/audio.wav"
                        ),
                    ],
                    underlyingErrorDescription: "Could not finish export."
                )

                let notification = CaptureUserNotification.partialRecordingRetained(
                    error
                )

                try Expect.equal(
                    notification.title,
                    "Capture recording failed",
                    "partial.title"
                )

                try Expect.equal(
                    notification.message,
                    "Partial files were retained in capture-partial-test.",
                    "partial.message"
                )

                try Expect.equal(
                    notification.appleScriptDisplayNotificationSource,
                    #"display notification "Partial files were retained in capture-partial-test." with title "Capture recording failed""#,
                    "partial.applescript"
                )
            }

            Step("generic recording failure notification uses localized description") {
                let notification = CaptureUserNotification.recordingFailed(
                    CaptureError.videoCapture(
                        "Could not start screen stream."
                    )
                )

                try Expect.equal(
                    notification.title,
                    "Capture recording failed",
                    "generic.title"
                )

                try Expect.equal(
                    notification.message,
                    "Could not start screen stream.",
                    "generic.message"
                )
            }

            Step("notification script escapes AppleScript strings") {
                let notification = CaptureUserNotification(
                    title: #"Capture "recording" failed"#,
                    message: #"Path contains \ and "quotes"."#
                )

                try Expect.equal(
                    notification.appleScriptDisplayNotificationSource,
                    #"display notification "Path contains \\ and \"quotes\"." with title "Capture \"recording\" failed""#,
                    "escaping.applescript"
                )
            }
        }
    }
}
