import Foundation

public struct CaptureAudioRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let device: CaptureDevice
    public let durationSeconds: Int
    public let startedAt: Date

    public init(
        output: URL,
        device: CaptureDevice,
        durationSeconds: Int,
        startedAt: Date
    ) {
        self.output = output
        self.device = device
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
    }
}
