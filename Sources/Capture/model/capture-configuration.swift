import Foundation

public struct CaptureConfiguration: Sendable, Codable, Hashable {
    public let display: CaptureDisplay
    public let video: CaptureVideoOptions
    public let audio: CaptureAudioOptions
    public let systemAudio: CaptureSystemAudioOptions
    public let audioMix: CaptureAudioMixOptions
    public let container: CaptureContainer
    public let output: URL

    public init(
        display: CaptureDisplay = .main,
        video: CaptureVideoOptions,
        audio: CaptureAudioOptions,
        systemAudio: CaptureSystemAudioOptions = .disabled,
        audioMix: CaptureAudioMixOptions = .standard,
        container: CaptureContainer = .mov,
        output: URL
    ) throws {
        let output = try CaptureFileOutput(
            output
        )

        self.display = display
        self.video = video
        self.audio = audio
        self.systemAudio = systemAudio
        self.audioMix = audioMix
        self.container = container
        self.output = output.url
    }
}
