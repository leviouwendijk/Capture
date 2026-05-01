import Foundation

public struct CaptureUserNotification: Sendable, Codable, Hashable {
    public let title: String
    public let message: String

    public init(
        title: String,
        message: String
    ) {
        self.title = title
        self.message = message
    }
}

public extension CaptureUserNotification {
    static func partialRecordingRetained(
        _ error: CapturePartialRecordingError
    ) -> CaptureUserNotification {
        CaptureUserNotification(
            title: "Capture recording failed",
            message: "Partial files were retained in \(error.workingDirectory.lastPathComponent)."
        )
    }

    static func recordingFailed(
        _ error: Error
    ) -> CaptureUserNotification {
        CaptureUserNotification(
            title: "Capture recording failed",
            message: error.localizedDescription
        )
    }

    var appleScriptDisplayNotificationSource: String {
        "display notification \(Self.appleScriptString(message)) with title \(Self.appleScriptString(title))"
    }
}

private extension CaptureUserNotification {
    static func appleScriptString(
        _ value: String
    ) -> String {
        let escaped = value
            .replacingOccurrences(
                of: "\\",
                with: "\\\\"
            )
            .replacingOccurrences(
                of: "\"",
                with: "\\\""
            )

        return "\"\(escaped)\""
    }
}
