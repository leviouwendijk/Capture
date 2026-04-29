import Foundation

internal struct CaptureMuxAudioInput: Sendable, Codable, Hashable {
    let url: URL
    let role: CaptureMuxAudioRole
    let gain: Double
    let startOffsetSeconds: TimeInterval

    init(
        url: URL,
        role: CaptureMuxAudioRole,
        gain: Double,
        startOffsetSeconds: TimeInterval
    ) {
        self.url = url
        self.role = role
        self.gain = gain
        self.startOffsetSeconds = startOffsetSeconds
    }
}
