import AVFoundation
import CoreMedia
import Foundation

internal struct CameraVideoStreamSnapshot: Sendable, Hashable {
    internal let sampleCount: Int
    internal let droppedSampleCount: Int
    internal let writtenFrameCount: Int
    internal let writerFailureDescription: String?
    internal let lastSampleAt: Date?
    internal let lastWrittenFrameAt: Date?

    internal init(
        sampleCount: Int,
        droppedSampleCount: Int,
        writtenFrameCount: Int,
        writerFailureDescription: String?,
        lastSampleAt: Date?,
        lastWrittenFrameAt: Date?
    ) {
        self.sampleCount = sampleCount
        self.droppedSampleCount = droppedSampleCount
        self.writtenFrameCount = writtenFrameCount
        self.writerFailureDescription = writerFailureDescription
        self.lastSampleAt = lastSampleAt
        self.lastWrittenFrameAt = lastWrittenFrameAt
    }
}

internal final class CameraVideoStreamOutput: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate {
    let queue = DispatchQueue(
        label: "capture.camera.video.samples"
    )

    private let sink: any CameraVideoSink
    private let onFailure: (@Sendable (Error) -> Void)?

    private let lock = NSLock()

    private var sampleCount = 0
    private var droppedSampleCount = 0
    private var lastSampleAt: Date?
    private var lastWrittenFrameAt: Date?
    private var failureSignalled = false

    init(
        sink: any CameraVideoSink,
        onFailure: (@Sendable (Error) -> Void)? = nil
    ) {
        self.sink = sink
        self.onFailure = onFailure
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()

        lock.lock()
        sampleCount += 1
        lastSampleAt = now
        lock.unlock()

        let appended = sink.append(
            sampleBuffer
        )

        guard appended else {
            let sinkSnapshot = sink.snapshot()

            if let failureDescription = sinkSnapshot.failureDescription {
                signalFailureOnce(
                    CaptureError.videoCapture(
                        "Camera sink failed while recording. \(failureDescription)"
                    )
                )
            }

            return
        }

        lock.lock()
        lastWrittenFrameAt = now
        lock.unlock()
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
        let capturedLastSampleAt = lastSampleAt
        let capturedLastWrittenFrameAt = lastWrittenFrameAt

        lock.unlock()

        let sinkSnapshot = sink.snapshot()

        return CameraVideoStreamSnapshot(
            sampleCount: capturedSampleCount,
            droppedSampleCount: capturedDroppedSampleCount,
            writtenFrameCount: sinkSnapshot.frameCount,
            writerFailureDescription: sinkSnapshot.failureDescription,
            lastSampleAt: capturedLastSampleAt,
            lastWrittenFrameAt: capturedLastWrittenFrameAt
        )
    }

    @discardableResult
    func waitForStableRecording(
        timeoutSeconds: TimeInterval,
        minimumWrittenFrameCount: Int,
        deviceName: String
    ) async throws -> CameraVideoStreamSnapshot {
        let resolvedTimeoutSeconds = max(
            0.25,
            timeoutSeconds
        )
        let resolvedMinimumWrittenFrameCount = max(
            1,
            minimumWrittenFrameCount
        )

        let deadline = Date().addingTimeInterval(
            resolvedTimeoutSeconds
        )

        while Date() < deadline {
            let capturedSnapshot = snapshot()

            if let failureDescription = capturedSnapshot.writerFailureDescription {
                throw CaptureError.videoCapture(
                    "Camera \(deviceName) delivered \(capturedSnapshot.sampleCount) sample callback(s), but the camera sink failed before stable startup. \(failureDescription)"
                )
            }

            if capturedSnapshot.writtenFrameCount >= resolvedMinimumWrittenFrameCount {
                return capturedSnapshot
            }

            try await Task.sleep(
                nanoseconds: 25_000_000
            )
        }

        let capturedSnapshot = snapshot()

        if let failureDescription = capturedSnapshot.writerFailureDescription {
            throw CaptureError.videoCapture(
                "Camera \(deviceName) delivered \(capturedSnapshot.sampleCount) sample callback(s), but the camera sink failed before stable startup. \(failureDescription)"
            )
        }

        guard capturedSnapshot.writtenFrameCount >= resolvedMinimumWrittenFrameCount else {
            throw CaptureError.videoCapture(
                "Camera \(deviceName) did not record stable usable frames within \(String(format: "%.2f", resolvedTimeoutSeconds))s. Sample callbacks: \(capturedSnapshot.sampleCount). Dropped callbacks: \(capturedSnapshot.droppedSampleCount). Written frames: \(capturedSnapshot.writtenFrameCount). Required frames: \(resolvedMinimumWrittenFrameCount)."
            )
        }

        return capturedSnapshot
    }

    func startLivenessMonitor(
        deviceName: String,
        staleAfterSeconds: TimeInterval = 3,
        intervalSeconds: TimeInterval = 0.25
    ) -> Task<Void, Never> {
        Task {
            var lastWrittenFrameCount = snapshot().writtenFrameCount
            var lastProgressAt = Date()

            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        max(
                            0.05,
                            intervalSeconds
                        ) * 1_000_000_000
                    )
                )

                guard !Task.isCancelled else {
                    return
                }

                let capturedSnapshot = snapshot()

                if let failureDescription = capturedSnapshot.writerFailureDescription {
                    signalFailureOnce(
                        CaptureError.videoCapture(
                            "Camera \(deviceName) failed while recording. \(failureDescription)"
                        )
                    )

                    return
                }

                if capturedSnapshot.writtenFrameCount > lastWrittenFrameCount {
                    lastWrittenFrameCount = capturedSnapshot.writtenFrameCount
                    lastProgressAt = Date()
                    continue
                }

                guard capturedSnapshot.writtenFrameCount > 0 else {
                    continue
                }

                let staleSeconds = Date().timeIntervalSince(
                    lastProgressAt
                )

                guard staleSeconds >= staleAfterSeconds else {
                    continue
                }

                signalFailureOnce(
                    CaptureError.videoCapture(
                        "Camera \(deviceName) stopped producing recorded frames for \(String(format: "%.2f", staleSeconds))s. Sample callbacks: \(capturedSnapshot.sampleCount). Dropped callbacks: \(capturedSnapshot.droppedSampleCount). Written frames: \(capturedSnapshot.writtenFrameCount)."
                    )
                )

                return
            }
        }
    }
}

private extension CameraVideoStreamOutput {
    func signalFailureOnce(
        _ error: Error
    ) {
        lock.lock()

        guard !failureSignalled else {
            lock.unlock()
            return
        }

        failureSignalled = true
        lock.unlock()

        onFailure?(
            error
        )
    }
}
