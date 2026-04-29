import Foundation

public struct CaptureConfiguration: Sendable, Codable, Hashable {
    public let display: CaptureDisplay
    public let video: CaptureVideoOptions
    public let audio: CaptureAudioOptions
    public let systemAudio: CaptureSystemAudioOptions
    public let container: CaptureContainer
    public let output: URL

    public init(
        display: CaptureDisplay = .main,
        video: CaptureVideoOptions,
        audio: CaptureAudioOptions,
        systemAudio: CaptureSystemAudioOptions = .disabled,
        container: CaptureContainer = .mov,
        output: URL
    ) throws {
        guard !output.path.isEmpty else {
            throw CaptureError.missingOutput
        }

        self.display = display
        self.video = video
        self.audio = audio
        self.systemAudio = systemAudio
        self.container = container
        self.output = output
    }
}
