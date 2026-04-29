import AVFoundation
import Foundation

public struct CaptureRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let videoFrameCount: Int

    public init(
        output: URL,
        durationSeconds: Int,
        videoFrameCount: Int
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.videoFrameCount = videoFrameCount
    }
}

public final class CaptureSession: Sendable {
    public let configuration: CaptureConfiguration
    public let options: CaptureRecordOptions
    public let deviceProvider: any CaptureDeviceProvider

    public init(
        configuration: CaptureConfiguration,
        options: CaptureRecordOptions = .standard,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) {
        self.configuration = configuration
        self.options = options
        self.deviceProvider = deviceProvider
    }

    @discardableResult
    public func start() async throws -> CaptureRecordingResult {
        let stopSignal = CaptureStopSignal()

        Task {
            try? await Task.sleep(
                nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000
            )

            stopSignal.stop()
        }

        return try await startUntilStopped(
            stopSignal: stopSignal
        )
    }

    @discardableResult
    public func startUntilStopped(
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureRecordingResult {
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "capture-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(
                at: workingDirectory
            )
        }

        let videoOutput = workingDirectory.appendingPathComponent(
            "video.mov"
        )
        let audioOutput = workingDirectory.appendingPathComponent(
            "audio.wav"
        )

        let videoConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            container: .mov,
            output: videoOutput
        )

        let audioConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            container: .mov,
            output: audioOutput
        )

        async let videoResult = ScreenCaptureVideoRecorder().recordVideoUntilStopped(
            configuration: videoConfiguration,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        )

        async let audioResult = CoreAudioRecorder().recordAudioUntilStopped(
            configuration: audioConfiguration,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        )

        let capturedVideoResult = try await videoResult
        let capturedAudioResult = try await audioResult

        try await CaptureAssetMuxer().mux(
            video: videoOutput,
            audio: audioOutput,
            output: configuration.output,
            container: configuration.container
        )

        return CaptureRecordingResult(
            output: configuration.output,
            durationSeconds: max(
                capturedVideoResult.durationSeconds,
                capturedAudioResult.durationSeconds
            ),
            videoFrameCount: capturedVideoResult.frameCount
        )
    }

    public func stop() async throws {
        throw CaptureError.recordingNotImplemented(
            "CaptureSession.stop() is not implemented for externally owned sessions yet."
        )
    }
}

private struct CaptureAssetMuxer: Sendable {
    func mux(
        video: URL,
        audio: URL,
        output: URL,
        container: CaptureContainer
    ) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(
            url: video
        )
        let audioAsset = AVURLAsset(
            url: audio
        )

        let videoTracks = try await videoAsset.loadTracks(
            withMediaType: .video
        )
        let audioTracks = try await audioAsset.loadTracks(
            withMediaType: .audio
        )

        guard let sourceVideoTrack = videoTracks.first else {
            throw CaptureError.videoCapture(
                "Could not find video track in temporary recording."
            )
        }

        guard let sourceAudioTrack = audioTracks.first else {
            throw CaptureError.audioCapture(
                "Could not find audio track in temporary recording."
            )
        }

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw CaptureError.videoCapture(
                "Could not create muxed video track."
            )
        }

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw CaptureError.audioCapture(
                "Could not create muxed audio track."
            )
        }

        let videoDuration = try await videoAsset.load(
            .duration
        )
        let audioDuration = try await audioAsset.load(
            .duration
        )

        try videoTrack.insertTimeRange(
            CMTimeRange(
                start: .zero,
                duration: videoDuration
            ),
            of: sourceVideoTrack,
            at: .zero
        )

        try audioTrack.insertTimeRange(
            CMTimeRange(
                start: .zero,
                duration: audioDuration
            ),
            of: sourceAudioTrack,
            at: .zero
        )

        if FileManager.default.fileExists(
            atPath: output.path
        ) {
            try FileManager.default.removeItem(
                at: output
            )
        }

        try await export(
            composition: composition,
            output: output,
            fileType: fileType(
                for: container
            )
        )
    }
}

private extension CaptureAssetMuxer {
    func fileType(
        for container: CaptureContainer
    ) -> AVFileType {
        switch container {
        case .mov:
            return .mov

        case .mp4:
            return .mp4
        }
    }

    func export(
        composition: AVMutableComposition,
        output: URL,
        fileType: AVFileType
    ) async throws {
        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw CaptureError.videoCapture(
                "Could not create asset exporter."
            )
        }

        exporter.outputURL = output
        exporter.outputFileType = fileType
        exporter.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exporter.status == .completed else {
            throw exporter.error.map(Self.describe)
                .map(CaptureError.videoCapture)
                ?? CaptureError.videoCapture(
                    "Could not mux audio and video."
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
