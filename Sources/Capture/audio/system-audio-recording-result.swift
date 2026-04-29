import Foundation

public struct CaptureSystemAudioRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let sampleBufferCount: Int
    public let startedAt: Date
    public let firstSampleAt: Date?
    public let firstPresentationTimeSeconds: Double?

    public init(
        output: URL,
        durationSeconds: Int,
        sampleBufferCount: Int,
        startedAt: Date,
        firstSampleAt: Date?,
        firstPresentationTimeSeconds: Double?
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.sampleBufferCount = sampleBufferCount
        self.startedAt = startedAt
        self.firstSampleAt = firstSampleAt
        self.firstPresentationTimeSeconds = firstPresentationTimeSeconds
    }
}
