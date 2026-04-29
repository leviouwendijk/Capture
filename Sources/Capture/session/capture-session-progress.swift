import Foundation

public enum CaptureSessionProgress: Sendable, Codable, Hashable {
    case recordingStopped(
        durationSeconds: TimeInterval
    )
    case exportStarted(
        mode: CaptureExportMode
    )
    case exportFinished(
        mode: CaptureExportMode
    )
}

public typealias CaptureSessionProgressHandler =
    @Sendable (CaptureSessionProgress) async -> Void
