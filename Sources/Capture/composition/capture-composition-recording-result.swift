import Foundation

public struct CaptureCompositionRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let video: CaptureResolvedVideoOptions
    public let screenFrameCount: Int
    public let cameraFrameCount: Int
    public let audioTrackCount: Int
    public let audioLayout: CaptureAudioLayout
    public let microphoneGain: Double
    public let systemGain: Double
    public let microphoneStartOffsetSeconds: TimeInterval
    public let systemAudioStartOffsetSeconds: TimeInterval?

    public init(
        output: URL,
        durationSeconds: Int,
        video: CaptureResolvedVideoOptions,
        screenFrameCount: Int,
        cameraFrameCount: Int,
        audioTrackCount: Int,
        audioLayout: CaptureAudioLayout,
        microphoneGain: Double,
        systemGain: Double,
        microphoneStartOffsetSeconds: TimeInterval,
        systemAudioStartOffsetSeconds: TimeInterval?
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.video = video
        self.screenFrameCount = screenFrameCount
        self.cameraFrameCount = cameraFrameCount
        self.audioTrackCount = audioTrackCount
        self.audioLayout = audioLayout
        self.microphoneGain = microphoneGain
        self.systemGain = systemGain
        self.microphoneStartOffsetSeconds = microphoneStartOffsetSeconds
        self.systemAudioStartOffsetSeconds = systemAudioStartOffsetSeconds
    }
}
