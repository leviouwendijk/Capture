import Foundation
import ScreenCaptureKit

internal final class ScreenCaptureSystemAudioStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    let queue = DispatchQueue(
        label: "capture.system-audio.samples"
    )

    private let writer: ScreenCaptureSystemAudioWriter
    private let stopSignal: CaptureStopSignal?
    private let lock = NSLock()

    private var stopError: Error?

    init(
        writer: ScreenCaptureSystemAudioWriter,
        stopSignal: CaptureStopSignal? = nil
    ) {
        self.writer = writer
        self.stopSignal = stopSignal
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
            CaptureError.audioCapture(
                Self.describe(
                    error
                )
            )
        )

        stopSignal?.stop()
    }
}

private extension ScreenCaptureSystemAudioStreamOutput {
    static func describe(
        _ error: Error
    ) -> String {
        let nsError = error as NSError

        return "System audio stream stopped unexpectedly. \(nsError.localizedDescription) domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)"
    }
}
