import Foundation
import ScreenCaptureKit

internal final class ScreenCaptureSystemAudioStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    let queue = DispatchQueue(
        label: "capture.system-audio.samples"
    )

    private let writer: ScreenCaptureSystemAudioWriter
    private let lock = NSLock()

    private var stopError: Error?

    init(
        writer: ScreenCaptureSystemAudioWriter
    ) {
        self.writer = writer
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio,
              sampleBuffer.isValid,
              CMSampleBufferDataIsReady(
                sampleBuffer
              ) else {
            return
        }

        writer.append(
            sampleBuffer
        )
    }

    func stream(
        _ stream: SCStream,
        didStopWithError error: Error
    ) {
        lock.lock()
        stopError = error
        lock.unlock()

        writer.fail(
            error
        )
    }
}
