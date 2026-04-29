import Foundation

public struct CaptureVideoOptions: Sendable, Codable, Hashable {
    public let width: Int
    public let height: Int
    public let fps: Int
    public let cursor: Bool
    public let codec: CaptureVideoCodec
    public let quality: CaptureVideoQuality
    public let bitrate: Int

    public init(
        width: Int = 1920,
        height: Int = 1080,
        fps: Int = 24,
        cursor: Bool = true,
        codec: CaptureVideoCodec = .h264,
        quality: CaptureVideoQuality = .standard,
        bitrate: Int? = nil
    ) throws {
        guard width > 0, height > 0 else {
            throw CaptureError.invalidVideoSize(
                width: width,
                height: height
            )
        }

        guard fps > 0 else {
            throw CaptureError.invalidFrameRate(
                fps
            )
        }

        let resolvedBitrate = bitrate ?? quality.recommendedBitrate(
            width: width,
            height: height,
            fps: fps
        )

        guard resolvedBitrate > 0 else {
            throw CaptureError.invalidVideoBitrate(
                resolvedBitrate
            )
        }

        self.width = width
        self.height = height
        self.fps = fps
        self.cursor = cursor
        self.codec = codec
        self.quality = quality
        self.bitrate = resolvedBitrate
    }
}

public struct CaptureAudioOptions: Sendable, Codable, Hashable {
    public let device: CaptureAudioDevice
    public let sampleRate: Int
    public let channel: Int
    public let codec: CaptureAudioCodec

    public init(
        device: CaptureAudioDevice = .systemDefault,
        sampleRate: Int = 48_000,
        channel: Int = 1,
        codec: CaptureAudioCodec = .pcm
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
    }
}
