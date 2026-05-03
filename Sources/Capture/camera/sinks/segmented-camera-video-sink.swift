import AVFoundation
import Foundation

internal final class SegmentedCameraVideoSink: CameraVideoSink, @unchecked Sendable {
    private let baseOutput: URL
    private let container: CaptureContainer
    private let video: CaptureVideoOptions
    private let lock = NSLock()

    private var current: CameraVideoFileSink?
    private var completedSegments: [CaptureCameraVideoSegment] = []
    private var nextIndex = 0
    private var failure: Error?
    private var finished = false

    internal init(
        output: URL,
        container: CaptureContainer,
        video: CaptureVideoOptions
    ) throws {
        self.baseOutput = output
        self.container = container
        self.video = video
        self.current = try CameraVideoFileSink(
            output: output,
            index: 0,
            startOffsetSeconds: 0,
            container: container,
            video: video
        )
        self.nextIndex = 1
    }

    @discardableResult
    internal func append(
        _ sampleBuffer: CMSampleBuffer
    ) -> Bool {
        guard let capturedCurrent = currentForAppend() else {
            return false
        }

        let appended = capturedCurrent.append(
            sampleBuffer
        )

        if !appended,
           let failureDescription = capturedCurrent.snapshot().failureDescription {
            fail(
                CaptureError.videoCapture(
                    failureDescription
                )
            )
        }

        return appended
    }

    internal func snapshot() -> CameraVideoWriterSnapshot {
        let capturedState = snapshotState()
        let currentSnapshot = capturedState.current?.snapshot()

        let completedFrameCount = capturedState.completedSegments.reduce(
            0
        ) { partial, segment in
            partial + segment.frameCount
        }

        return CameraVideoWriterSnapshot(
            frameCount: completedFrameCount + (currentSnapshot?.frameCount ?? 0),
            started: !capturedState.completedSegments.isEmpty
                || (currentSnapshot?.started ?? false),
            finished: capturedState.finished,
            failureDescription: capturedState.failure.map(describe)
                ?? currentSnapshot?.failureDescription
        )
    }

    internal func fail(
        _ error: Error
    ) {
        let capturedCurrent = recordFailure(
            error
        )

        capturedCurrent?.fail(
            error
        )
    }

    internal func cancel() {
        let capturedCurrent = markCancelled()

        capturedCurrent?.cancel()
    }

    internal func finish() async throws -> CameraVideoSinkFinishResult {
        let prepared = try prepareFinish()

        let currentResult: CameraVideoSinkFinishResult

        do {
            currentResult = try await prepared.current.finish()
        } catch {
            fail(
                error
            )

            throw error
        }

        let capturedSegments = completeFinish(
            currentResult
        )

        guard let firstSegment = capturedSegments.first else {
            throw CaptureError.videoCapture(
                "Camera segmented sink finished without segments."
            )
        }

        let frameCount = capturedSegments.reduce(
            0
        ) { partial, segment in
            partial + segment.frameCount
        }

        return CameraVideoSinkFinishResult(
            output: firstSegment.output,
            segments: capturedSegments,
            frameCount: frameCount,
            video: firstSegment.video,
            firstSampleAt: firstSegment.firstSampleAt,
            firstPresentationTimeSeconds: firstSegment.firstPresentationTimeSeconds
        )
    }

    internal func startNextSegment(
        startOffsetSeconds: TimeInterval
    ) async throws {
        let prepared = try prepareNextSegment()

        if let capturedCurrent = prepared.current {
            do {
                let finishedSegment = try await capturedCurrent.finish()

                appendCompletedSegments(
                    finishedSegment.segments
                )
            } catch {
                fail(
                    error
                )

                throw error
            }
        }

        let next = try CameraVideoFileSink(
            output: segmentOutput(
                index: prepared.index
            ),
            index: prepared.index,
            startOffsetSeconds: startOffsetSeconds,
            container: container,
            video: video
        )

        installCurrent(
            next
        )
    }
}

private struct SegmentedCameraVideoSinkSnapshotState {
    let current: CameraVideoFileSink?
    let completedSegments: [CaptureCameraVideoSegment]
    let failure: Error?
    let finished: Bool
}

private struct SegmentedCameraVideoSinkFinishPreparation {
    let current: CameraVideoFileSink
}

private struct SegmentedCameraVideoSinkNextSegmentPreparation {
    let current: CameraVideoFileSink?
    let index: Int
}

private extension SegmentedCameraVideoSink {
    func currentForAppend() -> CameraVideoFileSink? {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !finished,
              failure == nil else {
            return nil
        }

        return current
    }

    func snapshotState() -> SegmentedCameraVideoSinkSnapshotState {
        lock.lock()
        defer {
            lock.unlock()
        }

        return SegmentedCameraVideoSinkSnapshotState(
            current: current,
            completedSegments: completedSegments,
            failure: failure,
            finished: finished
        )
    }

    func recordFailure(
        _ error: Error
    ) -> CameraVideoFileSink? {
        lock.lock()
        defer {
            lock.unlock()
        }

        if failure == nil {
            failure = error
        }

        return current
    }

    func markCancelled() -> CameraVideoFileSink? {
        lock.lock()
        defer {
            lock.unlock()
        }

        finished = true

        let capturedCurrent = current
        current = nil

        return capturedCurrent
    }

    func prepareFinish() throws -> SegmentedCameraVideoSinkFinishPreparation {
        lock.lock()
        defer {
            lock.unlock()
        }

        if let failure {
            finished = true

            let capturedCurrent = current
            current = nil

            capturedCurrent?.cancel()

            throw failure
        }

        guard let capturedCurrent = current else {
            throw CaptureError.videoCapture(
                "Camera segmented sink has no active segment."
            )
        }

        current = nil

        return SegmentedCameraVideoSinkFinishPreparation(
            current: capturedCurrent
        )
    }

    func completeFinish(
        _ currentResult: CameraVideoSinkFinishResult
    ) -> [CaptureCameraVideoSegment] {
        lock.lock()
        defer {
            lock.unlock()
        }

        completedSegments.append(
            contentsOf: currentResult.segments
        )

        finished = true

        return completedSegments
    }

    func prepareNextSegment() throws -> SegmentedCameraVideoSinkNextSegmentPreparation {
        lock.lock()
        defer {
            lock.unlock()
        }

        if let failure {
            throw failure
        }

        guard !finished else {
            throw CaptureError.videoCapture(
                "Camera segmented sink is already finished."
            )
        }

        let capturedCurrent = current
        current = nil

        let index = nextIndex
        nextIndex += 1

        return SegmentedCameraVideoSinkNextSegmentPreparation(
            current: capturedCurrent,
            index: index
        )
    }

    func appendCompletedSegments(
        _ segments: [CaptureCameraVideoSegment]
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }

        completedSegments.append(
            contentsOf: segments
        )
    }

    func installCurrent(
        _ next: CameraVideoFileSink
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }

        current = next
    }

    func segmentOutput(
        index: Int
    ) -> URL {
        guard index > 0 else {
            return baseOutput
        }

        let directory = baseOutput.deletingLastPathComponent()
        let basename = baseOutput.deletingPathExtension().lastPathComponent
        let pathExtension = baseOutput.pathExtension

        return directory.appendingPathComponent(
            "\(basename)-\(String(format: "%03d", index)).\(pathExtension)"
        )
    }

    func describe(
        _ error: Error
    ) -> String {
        let nsError = error as NSError

        return "\(nsError.localizedDescription) domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)"
    }
}
