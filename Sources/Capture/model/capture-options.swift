import Foundation

public struct CaptureResolvedVideoOptions: Sendable, Codable, Hashable {
    public let width: Int
    public let height: Int
    public let fps: Int
    public let cursor: Bool
    public let codec: CaptureVideoCodec
    public let quality: CaptureVideoQuality
    public let bitrate: Int

    public init(
        width: Int,
        height: Int,
        fps: Int,
        cursor: Bool,
        codec: CaptureVideoCodec,
        quality: CaptureVideoQuality,
        bitrate: Int
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

        guard bitrate > 0 else {
            throw CaptureError.invalidVideoBitrate(
                bitrate
            )
        }

        self.width = width
        self.height = height
        self.fps = fps
        self.cursor = cursor
        self.codec = codec
        self.quality = quality
        self.bitrate = bitrate
    }
}

public struct CaptureVideoOptions: Sendable, Codable, Hashable {
    public let width: Int?
    public let height: Int?
    public let fps: Int
    public let cursor: Bool
    public let codec: CaptureVideoCodec
    public let quality: CaptureVideoQuality
    public let bitrate: Int?

    public init(
        width: Int? = nil,
        height: Int? = nil,
        fps: Int = 24,
        cursor: Bool = true,
        codec: CaptureVideoCodec = .h264,
        quality: CaptureVideoQuality = .standard,
        bitrate: Int? = nil
    ) throws {
        if let width,
           width <= 0 {
            throw CaptureError.invalidVideoSize(
                width: width,
                height: height ?? 0
            )
        }

        if let height,
           height <= 0 {
            throw CaptureError.invalidVideoSize(
                width: width ?? 0,
                height: height
            )
        }

        guard fps > 0 else {
            throw CaptureError.invalidFrameRate(
                fps
            )
        }

        if let bitrate,
           bitrate <= 0 {
            throw CaptureError.invalidVideoBitrate(
                bitrate
            )
        }

        self.width = width
        self.height = height
        self.fps = fps
        self.cursor = cursor
        self.codec = codec
        self.quality = quality
        self.bitrate = bitrate
    }

    public func resolved(
        displaySize: CaptureVideoSize
    ) throws -> CaptureResolvedVideoOptions {
        let size = try resolvedSize(
            displaySize: displaySize
        )
        let resolvedBitrate = bitrate ?? quality.recommendedBitrate(
            width: size.width,
            height: size.height,
            fps: fps
        )

        return try CaptureResolvedVideoOptions(
            width: size.width,
            height: size.height,
            fps: fps,
            cursor: cursor,
            codec: codec,
            quality: quality,
            bitrate: resolvedBitrate
        )
    }
}

private extension CaptureVideoOptions {
    func resolvedSize(
        displaySize: CaptureVideoSize
    ) throws -> CaptureVideoSize {
        guard displaySize.width > 0,
              displaySize.height > 0 else {
            throw CaptureError.invalidVideoSize(
                width: displaySize.width,
                height: displaySize.height
            )
        }

        switch (
            width,
            height
        ) {
        case (.none, .none):
            return displaySize

        case (.some(let width), .some(let height)):
            return CaptureVideoSize(
                width: width,
                height: height
            )

        case (.some(let width), .none):
            return CaptureVideoSize(
                width: width,
                height: scaledHeight(
                    forWidth: width,
                    displaySize: displaySize
                )
            )

        case (.none, .some(let height)):
            return CaptureVideoSize(
                width: scaledWidth(
                    forHeight: height,
                    displaySize: displaySize
                ),
                height: height
            )
        }
    }

    func scaledHeight(
        forWidth width: Int,
        displaySize: CaptureVideoSize
    ) -> Int {
        max(
            1,
            Int(
                (
                    Double(width)
                        * Double(displaySize.height)
                        / Double(displaySize.width)
                ).rounded()
            )
        )
    }

    func scaledWidth(
        forHeight height: Int,
        displaySize: CaptureVideoSize
    ) -> Int {
        max(
            1,
            Int(
                (
                    Double(height)
                        * Double(displaySize.width)
                        / Double(displaySize.height)
                ).rounded()
            )
        )
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
