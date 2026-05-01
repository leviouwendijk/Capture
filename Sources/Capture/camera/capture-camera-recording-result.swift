import Foundation

public struct CaptureCameraRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let videoFrameCount: Int
    public let video: CaptureResolvedVideoOptions
    public let camera: CaptureDevice
    public let audioInput: CaptureDevice
    public let audioTrackCount: Int
    public let microphoneGain: Double
    public let microphoneStartOffsetSeconds: TimeInterval

    public init(
        output: URL,
        durationSeconds: Int,
        videoFrameCount: Int,
        video: CaptureResolvedVideoOptions,
        camera: CaptureDevice,
        audioInput: CaptureDevice,
        audioTrackCount: Int,
        microphoneGain: Double,
        microphoneStartOffsetSeconds: TimeInterval
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.videoFrameCount = videoFrameCount
        self.video = video
        self.camera = camera
        self.audioInput = audioInput
        self.audioTrackCount = audioTrackCount
        self.microphoneGain = microphoneGain
        self.microphoneStartOffsetSeconds = microphoneStartOffsetSeconds
    }
}
