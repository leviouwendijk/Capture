import AVFoundation
import Foundation

internal struct ScreenCaptureSystemAudioWriterFinishResult {
    let sampleBufferCount: Int
    let firstSampleAt: Date?
    let firstPresentationTimeSeconds: Double?
}

internal final class ScreenCaptureSystemAudioWriter: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let lock = NSLock()

    private var started = false
    private var finished = false
    private var sampleBufferCount = 0
    private var firstSampleAt: Date?
    private var firstPresentationTimeSeconds: Double?
    private var lastPresentationTime: CMTime?
    private var failure: Error?

    init(
        output: URL,
        systemAudio: CaptureSystemAudioOptions
    ) throws {
        let directory = output.deletingLastPathComponent()

        if !directory.path.isEmpty {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        if FileManager.default.fileExists(
            atPath: output.path
        ) {
            try FileManager.default.removeItem(
                at: output
            )
        }

        writer = try AVAssetWriter(
            outputURL: output,
            fileType: .m4a
        )

        input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: systemAudio.sampleRate,
                AVNumberOfChannelsKey: systemAudio.channelCount,
                AVEncoderBitRateKey: 192_000,
            ]
        )

        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(
            input
        ) else {
            throw CaptureError.audioCapture(
                "Could not add system audio input to asset writer."
            )
        }

        writer.add(
            input
        )
    }

    func append(
        _ sampleBuffer: CMSampleBuffer
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !finished,
              failure == nil else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(
            sampleBuffer
        )

        guard presentationTime.isValid else {
            return
        }

        if firstSampleAt == nil {
            firstSampleAt = Date()
            firstPresentationTimeSeconds = CMTimeGetSeconds(
                presentationTime
            )
        }

        if !started {
            guard writer.startWriting() else {
                failure = writer.error.map(Self.describe)
                    .map(CaptureError.audioCapture)
                    ?? CaptureError.audioCapture(
                        "Could not start system audio writer."
                    )
                return
            }

            writer.startSession(
                atSourceTime: presentationTime
            )
            started = true
        }

        guard input.isReadyForMoreMediaData else {
            return
        }

        guard input.append(
            sampleBuffer
        ) else {
            failure = writer.error.map(Self.describe)
                .map(CaptureError.audioCapture)
                ?? CaptureError.audioCapture(
                    "Could not append system audio sample buffer."
                )
            return
        }

        lastPresentationTime = presentationTime
        sampleBufferCount += 1
    }

    func fail(
        _ error: Error
    ) {
        lock.lock()
        failure = error
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        finished = true
        writer.cancelWriting()
        lock.unlock()
    }

    func finish() async throws -> ScreenCaptureSystemAudioWriterFinishResult {
        let result = try prepareFinish()

        try await finishWriting()

        return result
    }
}

internal extension ScreenCaptureSystemAudioWriter {
    func prepareFinish() throws -> ScreenCaptureSystemAudioWriterFinishResult {
        lock.lock()

        if let failure {
            finished = true
            writer.cancelWriting()
            lock.unlock()
            throw failure
        }

        guard started else {
            finished = true
            writer.cancelWriting()
            lock.unlock()
            throw CaptureError.audioCapture(
                "No system audio samples were captured."
            )
        }

        if let lastPresentationTime {
            writer.endSession(
                atSourceTime: lastPresentationTime
            )
        }

        input.markAsFinished()
        finished = true

        let result = ScreenCaptureSystemAudioWriterFinishResult(
            sampleBufferCount: sampleBufferCount,
            firstSampleAt: firstSampleAt,
            firstPresentationTimeSeconds: firstPresentationTimeSeconds
        )

        lock.unlock()

        return result
    }

    func finishWriting() async throws {
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        guard writer.status == .completed else {
            throw writer.error.map(Self.describe)
                .map(CaptureError.audioCapture)
                ?? CaptureError.audioCapture(
                    "System audio writer did not finish successfully."
                )
        }
    }

    static func describe(
        _ error: Error
    ) -> String {
        let nsError = error as NSError

        return "\(nsError.localizedDescription) domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)"
    }
}
