import AVFoundation
import Foundation

internal final class CameraVideoStreamOutput: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let queue = DispatchQueue(
        label: "capture.camera.video.samples"
    )

    private let writer: CameraVideoWriter
    private let lock = NSLock()

    private var sampleCount = 0
    private var droppedSampleCount = 0

    init(
        writer: CameraVideoWriter
    ) {
        self.writer = writer
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        lock.lock()
        sampleCount += 1
        lock.unlock()

        writer.append(
            sampleBuffer
        )
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        lock.lock()
        droppedSampleCount += 1
        lock.unlock()
    }
}
