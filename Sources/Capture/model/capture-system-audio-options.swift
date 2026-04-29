public struct CaptureSystemAudioOptions: Sendable, Codable, Hashable {
    public static let disabled = CaptureSystemAudioOptions(
        uncheckedEnabled: false,
        sampleRate: 48_000,
        channelCount: 2,
        excludesCurrentProcessAudio: true
    )

    public let enabled: Bool
    public let sampleRate: Int
    public let channelCount: Int
    public let excludesCurrentProcessAudio: Bool

    public init(
        enabled: Bool = false,
        sampleRate: Int = 48_000,
        channelCount: Int = 2,
        excludesCurrentProcessAudio: Bool = true
    ) throws {
        guard sampleRate > 0 else {
            throw CaptureError.invalidSampleRate(
                sampleRate
            )
        }

        guard channelCount > 0 else {
            throw CaptureError.invalidChannel(
                channelCount
            )
        }

        self.enabled = enabled
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.excludesCurrentProcessAudio = excludesCurrentProcessAudio
    }

    private init(
        uncheckedEnabled enabled: Bool,
        sampleRate: Int,
        channelCount: Int,
        excludesCurrentProcessAudio: Bool
    ) {
        self.enabled = enabled
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.excludesCurrentProcessAudio = excludesCurrentProcessAudio
    }
}
