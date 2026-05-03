import Foundation

public struct CaptureCameraVideoRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let camera: CaptureDevice
    public let durationSeconds: Int
    public let frameCount: Int
    public let video: CaptureResolvedVideoOptions
    public let startedAt: Date
    public let startedHostTimeSeconds: TimeInterval
    public let firstSampleAt: Date?
    public let firstPresentationTimeSeconds: Double?
    public let segments: [CaptureCameraVideoSegment]

    public init(
        output: URL,
        camera: CaptureDevice,
        durationSeconds: Int,
        frameCount: Int,
        video: CaptureResolvedVideoOptions,
        startedAt: Date,
        startedHostTimeSeconds: TimeInterval,
        firstSampleAt: Date?,
        firstPresentationTimeSeconds: Double?,
        segments: [CaptureCameraVideoSegment] = []
    ) {
        self.output = output
        self.camera = camera
        self.durationSeconds = durationSeconds
        self.frameCount = frameCount
        self.video = video
        self.startedAt = startedAt
        self.startedHostTimeSeconds = startedHostTimeSeconds
        self.firstSampleAt = firstSampleAt
        self.firstPresentationTimeSeconds = firstPresentationTimeSeconds
        self.segments = segments
    }
}
