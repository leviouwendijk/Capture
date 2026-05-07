import AVFoundation
// import CoreMedia
import Foundation

internal struct CameraVideoSinkFinishResult: Sendable, Hashable {
    internal let output: URL
    internal let segments: [CaptureCameraVideoSegment]
    internal let frameCount: Int
    internal let video: CaptureResolvedVideoOptions
    internal let firstSampleAt: Date?
    internal let firstPresentationTimeSeconds: Double?

    internal init(
        output: URL,
        segments: [CaptureCameraVideoSegment],
        frameCount: Int,
        video: CaptureResolvedVideoOptions,
        firstSampleAt: Date?,
        firstPresentationTimeSeconds: Double?
    ) {
        self.output = output
        self.segments = segments
        self.frameCount = frameCount
        self.video = video
        self.firstSampleAt = firstSampleAt
        self.firstPresentationTimeSeconds = firstPresentationTimeSeconds
    }
}

internal protocol CameraVideoSink: AnyObject, Sendable {
    @discardableResult
    func append(
        _ sampleBuffer: CMSampleBuffer
    ) -> Bool

    func snapshot() -> CameraVideoWriterSnapshot

    func fail(
        _ error: Error
    )

    func cancel()

    func finish() async throws -> CameraVideoSinkFinishResult
}
