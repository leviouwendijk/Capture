import AVFoundation
import Foundation

internal struct CameraVideoStreamSnapshot: Sendable, Hashable {
    internal let sampleCount: Int
    internal let droppedSampleCount: Int
    internal let writtenFrameCount: Int
    internal let writerFailureDescription: String?

    internal init(
        sampleCount: Int,
        droppedSampleCount: Int,
        writtenFrameCount: Int,
        writerFailureDescription: String?
    ) {
        self.sampleCount = sampleCount
        self.droppedSampleCount = droppedSampleCount
        self.writtenFrameCount = writtenFrameCount
        self.writerFailureDescription = writerFailureDescription
    }
}

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

        _ = writer.append(
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

    func snapshot() -> CameraVideoStreamSnapshot {
        lock.lock()

        let capturedSampleCount = sampleCount
        let capturedDroppedSampleCount = droppedSampleCount

        lock.unlock()

        let writerSnapshot = writer.snapshot()

        return CameraVideoStreamSnapshot(
            sampleCount: capturedSampleCount,
            droppedSampleCount: capturedDroppedSampleCount,
            writtenFrameCount: writerSnapshot.frameCount,
            writerFailureDescription: writerSnapshot.failureDescription
        )
    }

    @discardableResult
    func waitForFirstRecordedFrame(
        timeoutSeconds: TimeInterval,
        deviceName: String
    ) async throws -> CameraVideoStreamSnapshot {
        let resolvedTimeoutSeconds = max(
            0.25,
            timeoutSeconds
        )
        let deadline = Date().addingTimeInterval(
            resolvedTimeoutSeconds
        )

        while Date() < deadline {
            let capturedSnapshot = snapshot()

            if let writerFailureDescription = capturedSnapshot.writerFailureDescription {
                throw CaptureError.videoCapture(
                    "Camera \(deviceName) delivered \(capturedSnapshot.sampleCount) sample callback(s), but the camera writer failed before accepting a frame. \(writerFailureDescription)"
                )
            }

            if capturedSnapshot.writtenFrameCount > 0 {
                return capturedSnapshot
            }

            try await Task.sleep(
                nanoseconds: 25_000_000
            )
        }

        let capturedSnapshot = snapshot()

        if let writerFailureDescription = capturedSnapshot.writerFailureDescription {
            throw CaptureError.videoCapture(
                "Camera \(deviceName) delivered \(capturedSnapshot.sampleCount) sample callback(s), but the camera writer failed before accepting a frame. \(writerFailureDescription)"
            )
        }

        guard capturedSnapshot.writtenFrameCount > 0 else {
            throw CaptureError.videoCapture(
                "Camera \(deviceName) did not record a usable frame within \(String(format: "%.2f", resolvedTimeoutSeconds))s. Sample callbacks: \(capturedSnapshot.sampleCount). Dropped callbacks: \(capturedSnapshot.droppedSampleCount). Written frames: \(capturedSnapshot.writtenFrameCount)."
            )
        }

        return capturedSnapshot
    }
}
