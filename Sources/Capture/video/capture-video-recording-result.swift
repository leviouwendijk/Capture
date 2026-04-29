// import AVFoundation
// import CoreGraphics
// import CoreMedia
import Foundation
// import ScreenCaptureKit

public struct CaptureVideoRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let display: CaptureDevice
    public let durationSeconds: Int
    public let frameCount: Int
    public let video: CaptureResolvedVideoOptions
    public let diagnostics: CaptureVideoRecordingDiagnostics
    public let startedAt: Date
    public let firstSampleAt: Date?
    public let firstPresentationTimeSeconds: Double?

    public init(
        output: URL,
        display: CaptureDevice,
        durationSeconds: Int,
        frameCount: Int,
        video: CaptureResolvedVideoOptions,
        diagnostics: CaptureVideoRecordingDiagnostics,
        startedAt: Date,
        firstSampleAt: Date?,
        firstPresentationTimeSeconds: Double?
    ) {
        self.output = output
        self.display = display
        self.durationSeconds = durationSeconds
        self.frameCount = frameCount
        self.video = video
        self.diagnostics = diagnostics
        self.startedAt = startedAt
        self.firstSampleAt = firstSampleAt
        self.firstPresentationTimeSeconds = firstPresentationTimeSeconds
    }
}

