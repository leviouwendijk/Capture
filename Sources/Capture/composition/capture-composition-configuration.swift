import Foundation

public struct CaptureCompositionConfiguration: Sendable, Codable, Hashable {
    public let display: CaptureDisplay
    public let camera: CaptureVideoInput
    public let video: CaptureVideoOptions
    public let audio: CaptureAudioOptions
    public let systemAudio: CaptureSystemAudioOptions
    public let audioMix: CaptureAudioMixOptions
    public let layout: CaptureCompositionLayout
    public let container: CaptureContainer
    public let output: URL

    public init(
        display: CaptureDisplay = .main,
        camera: CaptureVideoInput = .systemDefault,
        video: CaptureVideoOptions,
        audio: CaptureAudioOptions,
        systemAudio: CaptureSystemAudioOptions = .disabled,
        audioMix: CaptureAudioMixOptions = .standard,
        layout: CaptureCompositionLayout,
        container: CaptureContainer = .mov,
        output: URL
    ) throws {
        let output = try CaptureFileOutput(
            output
        )

        self.display = display
        self.camera = camera
        self.video = video
        self.audio = audio
        self.systemAudio = systemAudio
        self.audioMix = audioMix
        self.layout = layout
        self.container = container
        self.output = output.url
    }
}
