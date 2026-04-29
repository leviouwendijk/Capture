public enum CaptureAudioLayout: String, Sendable, Codable, Hashable, CaseIterable {
    case separate
    case mixed
}

public struct CaptureAudioMixOptions: Sendable, Codable, Hashable {
    public static let standard = CaptureAudioMixOptions(
        uncheckedLayout: .separate,
        microphoneGain: 1.0,
        systemGain: 1.0
    )

    public let layout: CaptureAudioLayout
    public let microphoneGain: Double
    public let systemGain: Double

    public init(
        layout: CaptureAudioLayout = .separate,
        microphoneGain: Double = 1.0,
        systemGain: Double = 1.0
    ) throws {
        try Self.validateGain(
            microphoneGain,
            label: "microphone"
        )
        try Self.validateGain(
            systemGain,
            label: "system"
        )

        self.layout = layout
        self.microphoneGain = microphoneGain
        self.systemGain = systemGain
    }

    private init(
        uncheckedLayout layout: CaptureAudioLayout,
        microphoneGain: Double,
        systemGain: Double
    ) {
        self.layout = layout
        self.microphoneGain = microphoneGain
        self.systemGain = systemGain
    }

    public var requiresAudioRendering: Bool {
        layout == .mixed
            || microphoneGain != 1.0
            || systemGain != 1.0
    }
}

private extension CaptureAudioMixOptions {
    static func validateGain(
        _ value: Double,
        label: String
    ) throws {
        guard value.isFinite,
              value >= 0 else {
            throw CaptureError.audioCapture(
                "Invalid \(label) gain: \(value). Gain must be a finite number greater than or equal to 0."
            )
        }
    }
}
