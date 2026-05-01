import Foundation

public struct CaptureAudioRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let device: CaptureDevice
    public let durationSeconds: Int
    public let startedAt: Date
    public let startedHostTimeSeconds: TimeInterval

    public init(
        output: URL,
        device: CaptureDevice,
        durationSeconds: Int,
        startedAt: Date,
        startedHostTimeSeconds: TimeInterval
    ) {
        self.output = output
        self.device = device
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
        self.startedHostTimeSeconds = startedHostTimeSeconds
    }
}
