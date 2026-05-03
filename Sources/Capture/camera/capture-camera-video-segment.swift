import Foundation

public struct CaptureCameraVideoSegment: Sendable, Codable, Hashable {
    public let index: Int
    public let output: URL
    public let frameCount: Int
    public let video: CaptureResolvedVideoOptions
    public let startOffsetSeconds: TimeInterval
    public let firstSampleAt: Date?
    public let firstPresentationTimeSeconds: Double?

    public init(
        index: Int,
        output: URL,
        frameCount: Int,
        video: CaptureResolvedVideoOptions,
        startOffsetSeconds: TimeInterval,
        firstSampleAt: Date?,
        firstPresentationTimeSeconds: Double?
    ) {
        self.index = index
        self.output = output
        self.frameCount = frameCount
        self.video = video
        self.startOffsetSeconds = startOffsetSeconds
        self.firstSampleAt = firstSampleAt
        self.firstPresentationTimeSeconds = firstPresentationTimeSeconds
    }
}
