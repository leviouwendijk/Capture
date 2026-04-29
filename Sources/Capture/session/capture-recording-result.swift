import Foundation

public struct CaptureRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let videoFrameCount: Int
    public let video: CaptureResolvedVideoOptions
    public let videoDiagnostics: CaptureVideoRecordingDiagnostics
    public let audioTrackCount: Int
    public let audioLayout: CaptureAudioLayout
    public let microphoneGain: Double
    public let systemGain: Double
    public let microphoneStartOffsetSeconds: TimeInterval
    public let systemAudioStartOffsetSeconds: TimeInterval?
    public let systemAudioSampleBufferCount: Int?

    public init(
        output: URL,
        durationSeconds: Int,
        videoFrameCount: Int,
        video: CaptureResolvedVideoOptions,
        videoDiagnostics: CaptureVideoRecordingDiagnostics,
        audioTrackCount: Int,
        audioLayout: CaptureAudioLayout,
        microphoneGain: Double,
        systemGain: Double,
        microphoneStartOffsetSeconds: TimeInterval,
        systemAudioStartOffsetSeconds: TimeInterval?,
        systemAudioSampleBufferCount: Int?
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.videoFrameCount = videoFrameCount
        self.video = video
        self.videoDiagnostics = videoDiagnostics
        self.audioTrackCount = audioTrackCount
        self.audioLayout = audioLayout
        self.microphoneGain = microphoneGain
        self.systemGain = systemGain
        self.microphoneStartOffsetSeconds = microphoneStartOffsetSeconds
        self.systemAudioStartOffsetSeconds = systemAudioStartOffsetSeconds
        self.systemAudioSampleBufferCount = systemAudioSampleBufferCount
    }
}
