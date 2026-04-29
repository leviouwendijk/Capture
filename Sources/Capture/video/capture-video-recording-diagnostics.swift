import Foundation

public struct CaptureVideoRecordingDiagnostics: Sendable, Codable, Hashable {
    public let requestedFramesPerSecond: Int
    public let recordedSeconds: TimeInterval
    public let totalSampleCount: Int
    public let screenSampleCount: Int
    public let validSampleCount: Int
    public let readySampleCount: Int
    public let completeFrameStatusCount: Int
    public let incompleteFrameStatusCount: Int
    public let missingFrameStatusCount: Int
    public let frameStatusRawValueCounts: [Int: Int]
    public let appendedFrameCount: Int
    public let finishedFrameCount: Int
    public let writerNotReadyFrameCount: Int
    public let missingPixelBufferFrameCount: Int
    public let invalidPresentationTimeFrameCount: Int
    public let appendFailedFrameCount: Int
    public let skippedAfterFinishedFrameCount: Int
    public let skippedAfterFailureFrameCount: Int
    public let stopErrorDescription: String?

    public init(
        requestedFramesPerSecond: Int,
        recordedSeconds: TimeInterval,
        totalSampleCount: Int,
        screenSampleCount: Int,
        validSampleCount: Int,
        readySampleCount: Int,
        completeFrameStatusCount: Int,
        incompleteFrameStatusCount: Int,
        missingFrameStatusCount: Int,
        frameStatusRawValueCounts: [Int: Int],
        appendedFrameCount: Int,
        finishedFrameCount: Int,
        writerNotReadyFrameCount: Int,
        missingPixelBufferFrameCount: Int,
        invalidPresentationTimeFrameCount: Int,
        appendFailedFrameCount: Int,
        skippedAfterFinishedFrameCount: Int,
        skippedAfterFailureFrameCount: Int,
        stopErrorDescription: String?
    ) {
        self.requestedFramesPerSecond = requestedFramesPerSecond
        self.recordedSeconds = recordedSeconds
        self.totalSampleCount = totalSampleCount
        self.screenSampleCount = screenSampleCount
        self.validSampleCount = validSampleCount
        self.readySampleCount = readySampleCount
        self.completeFrameStatusCount = completeFrameStatusCount
        self.incompleteFrameStatusCount = incompleteFrameStatusCount
        self.missingFrameStatusCount = missingFrameStatusCount
        self.frameStatusRawValueCounts = frameStatusRawValueCounts
        self.appendedFrameCount = appendedFrameCount
        self.finishedFrameCount = finishedFrameCount
        self.writerNotReadyFrameCount = writerNotReadyFrameCount
        self.missingPixelBufferFrameCount = missingPixelBufferFrameCount
        self.invalidPresentationTimeFrameCount = invalidPresentationTimeFrameCount
        self.appendFailedFrameCount = appendFailedFrameCount
        self.skippedAfterFinishedFrameCount = skippedAfterFinishedFrameCount
        self.skippedAfterFailureFrameCount = skippedAfterFailureFrameCount
        self.stopErrorDescription = stopErrorDescription
    }

    public var effectiveFramesPerSecond: Double {
        guard recordedSeconds > 0 else {
            return 0
        }

        return Double(finishedFrameCount) / recordedSeconds
    }

    public var completeSourceFramesPerSecond: Double {
        guard recordedSeconds > 0 else {
            return 0
        }

        return Double(completeFrameStatusCount) / recordedSeconds
    }

    public var requestedFrameBudget: Int {
        guard recordedSeconds > 0 else {
            return 0
        }

        return Int(
            (
                Double(requestedFramesPerSecond) * recordedSeconds
            ).rounded()
        )
    }

    public var missedFrameBudget: Int {
        max(
            0,
            requestedFrameBudget - finishedFrameCount
        )
    }

    public var appendSkipCount: Int {
        writerNotReadyFrameCount
            + missingPixelBufferFrameCount
            + invalidPresentationTimeFrameCount
            + appendFailedFrameCount
            + skippedAfterFinishedFrameCount
            + skippedAfterFailureFrameCount
    }

    public var incompleteSourceSampleCount: Int {
        incompleteFrameStatusCount + missingFrameStatusCount
    }

    public var summary: String {
        "samples total=\(totalSampleCount) screen=\(screenSampleCount) valid=\(validSampleCount) ready=\(readySampleCount) completeStatus=\(completeFrameStatusCount) incompleteStatus=\(incompleteFrameStatusCount) missingStatus=\(missingFrameStatusCount) statusRaw=\(frameStatusRawValueCounts) appended=\(appendedFrameCount) finished=\(finishedFrameCount) writerNotReady=\(writerNotReadyFrameCount) missingPixelBuffer=\(missingPixelBufferFrameCount) invalidPresentationTime=\(invalidPresentationTimeFrameCount) appendFailed=\(appendFailedFrameCount) skippedAfterFinished=\(skippedAfterFinishedFrameCount) skippedAfterFailure=\(skippedAfterFailureFrameCount) stopError=\(stopErrorDescription ?? "none")"
    }
}
