import AVFoundation
import Foundation

public struct CaptureRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let videoFrameCount: Int
    public let video: CaptureResolvedVideoOptions
    public let videoDiagnostics: CaptureVideoRecordingDiagnostics
    public let audioTrackCount: Int
    public let systemAudioSampleBufferCount: Int?

    public init(
        output: URL,
        durationSeconds: Int,
        videoFrameCount: Int,
        video: CaptureResolvedVideoOptions,
        videoDiagnostics: CaptureVideoRecordingDiagnostics,
        audioTrackCount: Int,
        systemAudioSampleBufferCount: Int?
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.videoFrameCount = videoFrameCount
        self.video = video
        self.videoDiagnostics = videoDiagnostics
        self.audioTrackCount = audioTrackCount
        self.systemAudioSampleBufferCount = systemAudioSampleBufferCount
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
        let systemAudioOutput = workingDirectory.appendingPathComponent(
            "system-audio.m4a"
        )

        let videoConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            systemAudio: configuration.systemAudio,
            container: .mov,
            output: videoOutput
        )

        let audioConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            systemAudio: configuration.systemAudio,
            container: .mov,
            output: audioOutput
        )

        let systemAudioConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            systemAudio: configuration.systemAudio,
            container: .mov,
            output: systemAudioOutput
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

        async let systemAudioResult = recordSystemAudioIfNeeded(
            configuration: systemAudioConfiguration,
            stopSignal: stopSignal
        )

        let capturedVideoResult = try await videoResult
        let capturedAudioResult = try await audioResult
        let capturedSystemAudioResult = try await systemAudioResult

        var audioOutputs = [
            audioOutput,
        ]

        if capturedSystemAudioResult != nil {
            audioOutputs.append(
                systemAudioOutput
            )
        }

        try await CaptureAssetMuxer().mux(
            video: videoOutput,
            audio: audioOutputs,
            output: configuration.output,
            container: configuration.container
        )

        return CaptureRecordingResult(
            output: configuration.output,
            durationSeconds: [
                capturedVideoResult.durationSeconds,
                capturedAudioResult.durationSeconds,
                capturedSystemAudioResult?.durationSeconds ?? 0,
            ].max() ?? 0,
            videoFrameCount: capturedVideoResult.frameCount,
            video: capturedVideoResult.video,
            videoDiagnostics: capturedVideoResult.diagnostics,
            audioTrackCount: audioOutputs.count,
            systemAudioSampleBufferCount: capturedSystemAudioResult?.sampleBufferCount
        )
    }

    public func stop() async throws {
        throw CaptureError.recordingNotImplemented(
            "CaptureSession.stop() is not implemented for externally owned sessions yet."
        )
    }
}

private extension CaptureSession {
    func recordSystemAudioIfNeeded(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureSystemAudioRecordingResult? {
        guard configuration.systemAudio.enabled else {
            return nil
        }

        return try await ScreenCaptureSystemAudioRecorder().recordSystemAudioUntilStopped(
            configuration: configuration,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        )
    }
}

private struct CaptureAssetMuxer: Sendable {
    func mux(
        video: URL,
        audio: [URL],
        output: URL,
        container: CaptureContainer
    ) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(
            url: video
        )

        let videoTracks = try await videoAsset.loadTracks(
            withMediaType: .video
        )

        guard let sourceVideoTrack = videoTracks.first else {
            throw CaptureError.videoCapture(
                "Could not find video track in temporary recording."
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

        let videoDuration = try await videoAsset.load(
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

        for audioURL in audio {
            try await addAudioTrack(
                from: audioURL,
                to: composition
            )
        }

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
    func addAudioTrack(
        from audioURL: URL,
        to composition: AVMutableComposition
    ) async throws {
        let audioAsset = AVURLAsset(
            url: audioURL
        )

        let audioTracks = try await audioAsset.loadTracks(
            withMediaType: .audio
        )

        guard let sourceAudioTrack = audioTracks.first else {
            throw CaptureError.audioCapture(
                "Could not find audio track in temporary recording \(audioURL.lastPathComponent)."
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

        let audioDuration = try await audioAsset.load(
            .duration
        )

        try audioTrack.insertTimeRange(
            CMTimeRange(
                start: .zero,
                duration: audioDuration
            ),
            of: sourceAudioTrack,
            at: .zero
        )
    }

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
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw CaptureError.videoCapture(
                "Could not create passthrough asset exporter."
            )
        }

        exporter.outputURL = output
        exporter.outputFileType = fileType
        exporter.shouldOptimizeForNetworkUse = false

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
