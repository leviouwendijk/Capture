import Capture
import Foundation

internal extension CaptureCLI {
    static func simulatePartialRecordingFailure() throws {
        throw CapturePartialRecordingError(
            workingDirectory: URL(
                fileURLWithPath: "/tmp/capture-test-failure-retained",
                isDirectory: true
            ),
            retainedFiles: [
                URL(
                    fileURLWithPath: "/tmp/capture-test-failure-retained/screen-video.mov"
                ),
                URL(
                    fileURLWithPath: "/tmp/capture-test-failure-retained/audio.wav"
                ),
                URL(
                    fileURLWithPath: "/tmp/capture-test-failure-retained/system-audio.m4a"
                ),
            ],
            underlyingErrorDescription: "Simulated Capture failure from `capturer test fail`."
        )
    }
}
