public enum CaptureVideoQuality: String, Sendable, Codable, Hashable, CaseIterable {
    case compact
    case standard
    case high
    case archival

    public var label: String {
        switch self {
        case .compact:
            return "compact"

        case .standard:
            return "standard"

        case .high:
            return "high"

        case .archival:
            return "archival"
        }
    }

    public var description: String {
        switch self {
        case .compact:
            return "smaller files, acceptable UI clarity"

        case .standard:
            return "good default for screen recording"

        case .high:
            return "sharper text and UI edges"

        case .archival:
            return "large files, near-source preservation"
        }
    }

    public func recommendedBitrate(
        width: Int,
        height: Int,
        fps: Int
    ) -> Int {
        let baseBitrate = baseBitrateAt1080p24
        let pixelScale = Double(width * height) / Double(1920 * 1080)
        let frameRateScale = Double(fps) / 24.0
        let scaled = Double(baseBitrate) * pixelScale * frameRateScale

        return max(
            minimumBitrate,
            Int(
                scaled.rounded()
            )
        )
    }
}

private extension CaptureVideoQuality {
    var baseBitrateAt1080p24: Int {
        switch self {
        case .compact:
            return 6_000_000

        case .standard:
            return 12_000_000

        case .high:
            return 24_000_000

        case .archival:
            return 50_000_000
        }
    }

    var minimumBitrate: Int {
        switch self {
        case .compact:
            return 2_500_000

        case .standard:
            return 6_000_000

        case .high:
            return 12_000_000

        case .archival:
            return 24_000_000
        }
    }
}
