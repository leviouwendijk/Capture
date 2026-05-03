import Foundation

public struct CaptureCameraConfiguration: Sendable, Codable, Hashable {
    public let camera: CaptureVideoInput
    public let video: CaptureVideoOptions
    public let audio: CaptureAudioOptions
    public let audioMix: CaptureAudioMixOptions
    public let container: CaptureContainer
    public let output: URL

    public init(
        camera: CaptureVideoInput = .systemDefault,
        video: CaptureVideoOptions,
        audio: CaptureAudioOptions,
        audioMix: CaptureAudioMixOptions = .standard,
        container: CaptureContainer = .mov,
        output: URL
    ) throws {
        let output = try CaptureFileOutput(
            output
        )

        self.camera = camera
        self.video = video
        self.audio = audio
        self.audioMix = audioMix
        self.container = container
        self.output = output.url
    }
}
