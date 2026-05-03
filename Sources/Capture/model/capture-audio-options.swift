import Foundation

public struct CaptureAudioOptions: Sendable, Codable, Hashable {
    public let device: CaptureAudioDevice
    public let sampleRate: Int
    public let channel: Int
    public let codec: CaptureAudioCodec
    public let sample: Audio.Sample

    public init(
        device: CaptureAudioDevice = .systemDefault,
        sampleRate: Int = 48_000,
        channel: Int = 1,
        codec: CaptureAudioCodec = .pcm,
        sample: Audio.Sample = .int16
    ) throws {
        guard sampleRate > 0 else {
            throw CaptureError.invalidSampleRate(
                sampleRate
            )
        }

        guard channel > 0 else {
            throw CaptureError.invalidChannel(
                channel
            )
        }

        self.device = device
        self.sampleRate = sampleRate
        self.channel = channel
        self.codec = codec
        self.sample = sample
    }
}
