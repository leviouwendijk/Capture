import Foundation

internal struct CaptureScreenMediaRecordingResult: Sendable {
    internal let video: CaptureVideoRecordingResult
    internal let systemAudio: CaptureSystemAudioRecordingResult?

    internal init(
        video: CaptureVideoRecordingResult,
        systemAudio: CaptureSystemAudioRecordingResult?
    ) {
        self.video = video
        self.systemAudio = systemAudio
    }
}
