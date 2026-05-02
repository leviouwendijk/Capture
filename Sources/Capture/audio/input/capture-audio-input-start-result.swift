import Foundation

public struct CaptureAudioInputStartResult: Sendable, Codable, Hashable {
    public let device: CaptureDevice
    public let sampleRate: Int
    public let channelCount: Int

    public init(
        device: CaptureDevice,
        sampleRate: Int,
        channelCount: Int
    ) {
        self.device = device
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}
