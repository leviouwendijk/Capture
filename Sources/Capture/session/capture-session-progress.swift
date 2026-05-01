import Foundation

public struct CaptureRecordingHealthSnapshot: Sendable, Codable, Hashable {
    public let screenVideoFrameCount: Int?
    public let cameraVideoFrameCount: Int?
    public let videoFrameCount: Int?
    public let videoMissedFrameBudget: Int?
    public let videoAppendSkipCount: Int?
    public let systemAudioEnabled: Bool
    public let systemAudioSampleBufferCount: Int?

    public init(
        screenVideoFrameCount: Int? = nil,
        cameraVideoFrameCount: Int? = nil,
        videoFrameCount: Int? = nil,
        videoMissedFrameBudget: Int? = nil,
        videoAppendSkipCount: Int? = nil,
        systemAudioEnabled: Bool = false,
        systemAudioSampleBufferCount: Int? = nil
    ) {
        self.screenVideoFrameCount = screenVideoFrameCount
        self.cameraVideoFrameCount = cameraVideoFrameCount
        self.videoFrameCount = videoFrameCount
        self.videoMissedFrameBudget = videoMissedFrameBudget
        self.videoAppendSkipCount = videoAppendSkipCount
        self.systemAudioEnabled = systemAudioEnabled
        self.systemAudioSampleBufferCount = systemAudioSampleBufferCount
    }

    public var briefDescription: String {
        let values = [
            screenVideoFrameCount.map {
                "screen frames: \($0)"
            },
            cameraVideoFrameCount.map {
                "camera frames: \($0)"
            },
            videoFrameCount.map {
                "video frames: \($0)"
            },
            systemAudioEnabled
                ? "system buffers: \(systemAudioSampleBufferCount ?? 0)"
                : nil,
        ]

        return values
            .compactMap { $0 }
            .joined(
                separator: "    "
            )
    }

    public var warningDescriptions: [String] {
        var warnings: [String] = []

        if let screenVideoFrameCount,
           screenVideoFrameCount == 0 {
            warnings.append(
                "screen video produced no frames"
            )
        }

        if let cameraVideoFrameCount,
           cameraVideoFrameCount == 0 {
            warnings.append(
                "camera video produced no frames"
            )
        }

        if let videoFrameCount,
           videoFrameCount == 0 {
            warnings.append(
                "video produced no frames"
            )
        }

        if systemAudioEnabled,
           (systemAudioSampleBufferCount ?? 0) == 0 {
            warnings.append(
                "system audio was enabled but produced no sample buffers"
            )
        }

        if let videoAppendSkipCount,
           videoAppendSkipCount > 0 {
            warnings.append(
                "video writer skipped \(videoAppendSkipCount) frames"
            )
        }

        if let videoMissedFrameBudget,
           videoMissedFrameBudget > 0 {
            warnings.append(
                "video missed \(videoMissedFrameBudget) frames against the requested frame budget"
            )
        }

        return warnings
    }
}

public enum CaptureSessionProgress: Sendable, Codable, Hashable {
    case recordingStarted(
        startedAt: Date
    )
    case recordingHealth(
        snapshot: CaptureRecordingHealthSnapshot
    )
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
