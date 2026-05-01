import Foundation

public struct CaptureCompositionVideoRenderingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let video: CaptureResolvedVideoOptions

    public init(
        output: URL,
        durationSeconds: Int,
        video: CaptureResolvedVideoOptions
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.video = video
    }
}
