import AVFoundation
// import CoreMedia
import Foundation

internal final class CameraVideoFileSink: CameraVideoSink, @unchecked Sendable {
    private let output: URL
    private let index: Int
    private let startOffsetSeconds: TimeInterval
    private let writer: CameraVideoWriter

    internal init(
        output: URL,
        index: Int = 0,
        startOffsetSeconds: TimeInterval = 0,
        container: CaptureContainer,
        video: CaptureVideoOptions
    ) throws {
        self.output = output
        self.index = index
        self.startOffsetSeconds = startOffsetSeconds
        self.writer = try CameraVideoWriter(
            output: output,
            container: container,
            video: video
        )
    }

    @discardableResult
    internal func append(
        _ sampleBuffer: CMSampleBuffer
    ) -> Bool {
        writer.append(
            sampleBuffer
        )
    }

    internal func snapshot() -> CameraVideoWriterSnapshot {
        writer.snapshot()
    }

    internal func fail(
        _ error: Error
    ) {
        writer.fail(
            error
        )
    }

    internal func cancel() {
        writer.cancel()
    }

    internal func finish() async throws -> CameraVideoSinkFinishResult {
        let result = try await writer.finish()

        let segment = CaptureCameraVideoSegment(
            index: index,
            output: output,
            frameCount: result.frameCount,
            video: result.video,
            startOffsetSeconds: startOffsetSeconds,
            firstSampleAt: result.firstSampleAt,
            firstPresentationTimeSeconds: result.firstPresentationTimeSeconds
        )

        return CameraVideoSinkFinishResult(
            output: output,
            segments: [
                segment,
            ],
            frameCount: result.frameCount,
            video: result.video,
            firstSampleAt: result.firstSampleAt,
            firstPresentationTimeSeconds: result.firstPresentationTimeSeconds
        )
    }
}
