import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

internal final class ScreenCaptureVideoStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    let queue = DispatchQueue(
        label: "capture.screen.video.samples"
    )

    private let writer: ScreenCaptureVideoWriter
    private let stopSignal: CaptureStopSignal?
    private let lock = NSLock()

    private var totalSampleCount = 0
    private var screenSampleCount = 0
    private var validSampleCount = 0
    private var readySampleCount = 0
    private var completeFrameStatusCount = 0
    private var capturedFirstCompleteSampleAt: Date?
    private var capturedFirstCompleteFramePresentationTimeSeconds: Double?
    private var incompleteFrameStatusCount = 0
    private var missingFrameStatusCount = 0
    private var frameStatusRawValueCounts: [Int: Int] = [:]
    private var appendedFrameCount = 0
    private var writerNotReadyFrameCount = 0
    private var missingPixelBufferFrameCount = 0
    private var invalidPresentationTimeFrameCount = 0
    private var appendFailedFrameCount = 0
    private var skippedAfterFinishedFrameCount = 0
    private var skippedAfterFailureFrameCount = 0
    private var stopError: Error?

    init(
        writer: ScreenCaptureVideoWriter,
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
        recordSample(
            sampleBuffer: sampleBuffer,
            type: type
        )

        guard type == .screen,
              sampleBuffer.isValid,
              CMSampleBufferDataIsReady(
                sampleBuffer
              ) else {
            return
        }

        switch frameStatus(
            for: sampleBuffer
        ) {
        case .complete:
            recordCompleteFrameStatus(
                sampleBuffer: sampleBuffer
            )

        case .incomplete(let rawValue):
            recordIncompleteFrameStatus(
                rawValue: rawValue
            )
            return

        case .missing:
            recordMissingFrameStatus()
            return
        }

        switch writer.append(
            sampleBuffer
        ) {
        case .appended:
            lock.lock()
            appendedFrameCount += 1
            lock.unlock()

        case .skipped(let reason):
            recordSkippedAppend(
                reason
            )
        }
    }

    func stream(
        _ stream: SCStream,
        didStopWithError error: Error
    ) {
        lock.lock()
        stopError = error
        lock.unlock()

        stopSignal?.stop()
    }

    func firstCompleteSampleAt() -> Date? {
        lock.lock()
        let value = capturedFirstCompleteSampleAt
        lock.unlock()

        return value
    }

    func firstCompleteFramePresentationTimeSeconds() -> Double? {
        lock.lock()
        let value = capturedFirstCompleteFramePresentationTimeSeconds
        lock.unlock()

        return value
    }

    func diagnostics(
        requestedFramesPerSecond: Int,
        recordedSeconds: TimeInterval,
        finishedFrameCount: Int?
    ) -> CaptureVideoRecordingDiagnostics {
        lock.lock()

        let diagnostics = CaptureVideoRecordingDiagnostics(
            requestedFramesPerSecond: requestedFramesPerSecond,
            recordedSeconds: recordedSeconds,
            totalSampleCount: totalSampleCount,
            screenSampleCount: screenSampleCount,
            validSampleCount: validSampleCount,
            readySampleCount: readySampleCount,
            completeFrameStatusCount: completeFrameStatusCount,
            incompleteFrameStatusCount: incompleteFrameStatusCount,
            missingFrameStatusCount: missingFrameStatusCount,
            frameStatusRawValueCounts: frameStatusRawValueCounts,
            appendedFrameCount: appendedFrameCount,
            finishedFrameCount: finishedFrameCount ?? appendedFrameCount,
            writerNotReadyFrameCount: writerNotReadyFrameCount,
            missingPixelBufferFrameCount: missingPixelBufferFrameCount,
            invalidPresentationTimeFrameCount: invalidPresentationTimeFrameCount,
            appendFailedFrameCount: appendFailedFrameCount,
            skippedAfterFinishedFrameCount: skippedAfterFinishedFrameCount,
            skippedAfterFailureFrameCount: skippedAfterFailureFrameCount,
            stopErrorDescription: stopError.map {
                ($0 as NSError).localizedDescription
            }
        )

        lock.unlock()

        return diagnostics
    }
}

internal extension ScreenCaptureVideoStreamOutput {
    func recordSample(
        sampleBuffer: CMSampleBuffer,
        type: SCStreamOutputType
    ) {
        lock.lock()
        totalSampleCount += 1

        if type == .screen {
            screenSampleCount += 1
        }

        if sampleBuffer.isValid {
            validSampleCount += 1
        }

        if CMSampleBufferDataIsReady(
            sampleBuffer
        ) {
            readySampleCount += 1
        }

        lock.unlock()
    }

    func frameStatus(
        for sampleBuffer: CMSampleBuffer
    ) -> ScreenCaptureFrameSampleStatus {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first,
              let rawValue = attachments[
                SCStreamFrameInfo.status
              ] as? Int else {
            return .missing
        }

        guard let status = SCFrameStatus(
            rawValue: rawValue
        ),
              status == .complete else {
            return .incomplete(
                rawValue: rawValue
            )
        }

        return .complete
    }

    func recordCompleteFrameStatus(
        sampleBuffer: CMSampleBuffer
    ) {
        lock.lock()

        if capturedFirstCompleteSampleAt == nil {
            capturedFirstCompleteSampleAt = Date()

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(
                sampleBuffer
            )

            if presentationTime.isValid {
                capturedFirstCompleteFramePresentationTimeSeconds = CMTimeGetSeconds(
                    presentationTime
                )
            }
        }

        completeFrameStatusCount += 1

        lock.unlock()
    }

    func recordIncompleteFrameStatus(
        rawValue: Int
    ) {
        lock.lock()
        incompleteFrameStatusCount += 1
        frameStatusRawValueCounts[
            rawValue,
            default: 0
        ] += 1
        lock.unlock()
    }

    func recordMissingFrameStatus() {
        lock.lock()
        missingFrameStatusCount += 1
        lock.unlock()
    }

    func recordSkippedAppend(
        _ reason: ScreenCaptureVideoAppendSkipReason
    ) {
        lock.lock()

        switch reason {
        case .finished:
            skippedAfterFinishedFrameCount += 1

        case .failed:
            skippedAfterFailureFrameCount += 1

        case .missingPixelBuffer:
            missingPixelBufferFrameCount += 1

        case .invalidPresentationTime:
            invalidPresentationTimeFrameCount += 1

        case .writerNotReady:
            writerNotReadyFrameCount += 1

        case .appendFailed:
            appendFailedFrameCount += 1
        }

        lock.unlock()
    }
}
