import AVFoundation
import Foundation

public struct CaptureRecordingResult: Sendable, Codable, Hashable {
    public let output: URL
    public let durationSeconds: Int
    public let videoFrameCount: Int
    public let video: CaptureResolvedVideoOptions
    public let videoDiagnostics: CaptureVideoRecordingDiagnostics
    public let audioTrackCount: Int
    public let audioLayout: CaptureAudioLayout
    public let microphoneGain: Double
    public let systemGain: Double
    public let microphoneStartOffsetSeconds: TimeInterval
    public let systemAudioStartOffsetSeconds: TimeInterval?
    public let systemAudioSampleBufferCount: Int?

    public init(
        output: URL,
        durationSeconds: Int,
        videoFrameCount: Int,
        video: CaptureResolvedVideoOptions,
        videoDiagnostics: CaptureVideoRecordingDiagnostics,
        audioTrackCount: Int,
        audioLayout: CaptureAudioLayout,
        microphoneGain: Double,
        systemGain: Double,
        microphoneStartOffsetSeconds: TimeInterval,
        systemAudioStartOffsetSeconds: TimeInterval?,
        systemAudioSampleBufferCount: Int?
    ) {
        self.output = output
        self.durationSeconds = durationSeconds
        self.videoFrameCount = videoFrameCount
        self.video = video
        self.videoDiagnostics = videoDiagnostics
        self.audioTrackCount = audioTrackCount
        self.audioLayout = audioLayout
        self.microphoneGain = microphoneGain
        self.systemGain = systemGain
        self.microphoneStartOffsetSeconds = microphoneStartOffsetSeconds
        self.systemAudioStartOffsetSeconds = systemAudioStartOffsetSeconds
        self.systemAudioSampleBufferCount = systemAudioSampleBufferCount
    }
}

public final class CaptureSession: Sendable {
    public let configuration: CaptureConfiguration
    public let options: CaptureRecordOptions
    public let deviceProvider: any CaptureDeviceProvider
    public let progress: CaptureSessionProgressHandler?

    public init(
        configuration: CaptureConfiguration,
        options: CaptureRecordOptions = .standard,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider(),
        progress: CaptureSessionProgressHandler? = nil
    ) {
        self.configuration = configuration
        self.options = options
        self.deviceProvider = deviceProvider
        self.progress = progress
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
            audioMix: configuration.audioMix,
            container: .mov,
            output: videoOutput
        )

        let audioConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            systemAudio: configuration.systemAudio,
            audioMix: configuration.audioMix,
            container: .mov,
            output: audioOutput
        )

        let systemAudioConfiguration = try CaptureConfiguration(
            display: configuration.display,
            video: configuration.video,
            audio: configuration.audio,
            systemAudio: configuration.systemAudio,
            audioMix: configuration.audioMix,
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

        let capturedDurationSeconds = [
            capturedVideoResult.durationSeconds,
            capturedAudioResult.durationSeconds,
            capturedSystemAudioResult?.durationSeconds ?? 0,
        ].max() ?? 0

        await report(
            .recordingStopped(
                durationSeconds: TimeInterval(
                    capturedDurationSeconds
                )
            )
        )

        let videoTimelineStart = capturedVideoResult.firstSampleAt
            ?? capturedVideoResult.startedAt

        let microphoneStartOffsetSeconds = normalizedTimelineOffset(
            capturedAudioResult.startedAt.timeIntervalSince(
                videoTimelineStart
            )
        )

        let systemAudioStartOffsetSeconds = capturedSystemAudioResult.map { result in
            if let videoPresentationTimeSeconds = capturedVideoResult.firstPresentationTimeSeconds,
               let systemPresentationTimeSeconds = result.firstPresentationTimeSeconds {
                return normalizedTimelineOffset(
                    systemPresentationTimeSeconds - videoPresentationTimeSeconds
                )
            }

            return normalizedTimelineOffset(
                (
                    result.firstSampleAt ?? result.startedAt
                ).timeIntervalSince(
                    videoTimelineStart
                )
            )
        }

        var audioInputs = [
            CaptureMuxAudioInput(
                url: audioOutput,
                role: .microphone,
                gain: configuration.audioMix.microphoneGain,
                startOffsetSeconds: microphoneStartOffsetSeconds
            ),
        ]

        if capturedSystemAudioResult != nil {
            audioInputs.append(
                CaptureMuxAudioInput(
                    url: systemAudioOutput,
                    role: .system,
                    gain: configuration.audioMix.systemGain,
                    startOffsetSeconds: systemAudioStartOffsetSeconds ?? 0
                )
            )
        }

        let exportMode: CaptureExportMode = configuration.audioMix.requiresAudioRendering
            ? .rendering
            : .passthrough

        await report(
            .exportStarted(
                mode: exportMode
            )
        )

        try await CaptureAssetMuxer().mux(
            video: videoOutput,
            audio: audioInputs,
            audioMix: configuration.audioMix,
            output: configuration.output,
            container: configuration.container
        )

        await report(
            .exportFinished(
                mode: exportMode
            )
        )

        return CaptureRecordingResult(
            output: configuration.output,
            durationSeconds: capturedDurationSeconds,
            videoFrameCount: capturedVideoResult.frameCount,
            video: capturedVideoResult.video,
            videoDiagnostics: capturedVideoResult.diagnostics,
            audioTrackCount: audioInputs.count,
            audioLayout: configuration.audioMix.layout,
            microphoneGain: configuration.audioMix.microphoneGain,
            systemGain: configuration.audioMix.systemGain,
            microphoneStartOffsetSeconds: microphoneStartOffsetSeconds,
            systemAudioStartOffsetSeconds: systemAudioStartOffsetSeconds,
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
    func normalizedTimelineOffset(
        _ offset: TimeInterval
    ) -> TimeInterval {
        guard offset.isFinite else {
            return 0
        }

        if abs(offset) < 0.010 {
            return 0
        }

        return offset
    }

    func report(
        _ event: CaptureSessionProgress
    ) async {
        guard let progress else {
            return
        }

        await progress(
            event
        )
    }

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

private enum CaptureMuxAudioRole: String, Sendable, Codable, Hashable {
    case microphone
    case system
}

private struct CaptureMuxAudioInput: Sendable, Codable, Hashable {
    let url: URL
    let role: CaptureMuxAudioRole
    let gain: Double
    let startOffsetSeconds: TimeInterval

    init(
        url: URL,
        role: CaptureMuxAudioRole,
        gain: Double,
        startOffsetSeconds: TimeInterval
    ) {
        self.url = url
        self.role = role
        self.gain = gain
        self.startOffsetSeconds = startOffsetSeconds
    }
}

private struct CaptureMuxedAudioTrack {
    let track: AVMutableCompositionTrack
    let input: CaptureMuxAudioInput
}

private struct CaptureAssetMuxer: Sendable {
    func mux(
        video: URL,
        audio: [CaptureMuxAudioInput],
        audioMix: CaptureAudioMixOptions,
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

        var audioTracks: [CaptureMuxedAudioTrack] = []

        for audioInput in audio {
            let audioTrack = try await addAudioTrack(
                from: audioInput,
                to: composition
            )

            audioTracks.append(
                CaptureMuxedAudioTrack(
                    track: audioTrack,
                    input: audioInput
                )
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
            ),
            audioMix: makeAudioMix(
                tracks: audioTracks,
                options: audioMix
            )
        )
    }
}

private extension CaptureAssetMuxer {
    func addAudioTrack(
        from input: CaptureMuxAudioInput,
        to composition: AVMutableComposition
    ) async throws -> AVMutableCompositionTrack {
        let audioAsset = AVURLAsset(
            url: input.url
        )

        let audioTracks = try await audioAsset.loadTracks(
            withMediaType: .audio
        )

        guard let sourceAudioTrack = audioTracks.first else {
            throw CaptureError.audioCapture(
                "Could not find \(input.role.rawValue) audio track in temporary recording \(input.url.lastPathComponent)."
            )
        }

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw CaptureError.audioCapture(
                "Could not create muxed \(input.role.rawValue) audio track."
            )
        }

        let audioDuration = try await audioAsset.load(
            .duration
        )

        let preferredTimescale = CMTimeScale(
            max(
                audioDuration.timescale,
                600
            )
        )

        let absoluteOffset = CMTime(
            seconds: abs(
                input.startOffsetSeconds
            ),
            preferredTimescale: preferredTimescale
        )

        let sourceStart: CMTime
        let destinationStart: CMTime

        if input.startOffsetSeconds < 0 {
            sourceStart = absoluteOffset
            destinationStart = .zero
        } else {
            sourceStart = .zero
            destinationStart = absoluteOffset
        }

        let availableDuration = CMTimeSubtract(
            audioDuration,
            sourceStart
        )

        guard CMTimeCompare(
            availableDuration,
            .zero
        ) > 0 else {
            throw CaptureError.audioCapture(
                "Could not align \(input.role.rawValue) audio track; computed source start exceeds audio duration."
            )
        }

        try audioTrack.insertTimeRange(
            CMTimeRange(
                start: sourceStart,
                duration: availableDuration
            ),
            of: sourceAudioTrack,
            at: destinationStart
        )

        return audioTrack
    }

    func makeAudioMix(
        tracks: [CaptureMuxedAudioTrack],
        options: CaptureAudioMixOptions
    ) -> AVMutableAudioMix? {
        guard options.requiresAudioRendering else {
            return nil
        }

        let mix = AVMutableAudioMix()

        mix.inputParameters = tracks.map { muxedTrack in
            let parameters = AVMutableAudioMixInputParameters(
                track: muxedTrack.track
            )

            parameters.setVolume(
                Float(
                    muxedTrack.input.gain
                ),
                at: .zero
            )

            return parameters
        }

        return mix
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
        fileType: AVFileType,
        audioMix: AVMutableAudioMix?
    ) async throws {
        let presetName: String

        if audioMix == nil {
            presetName = AVAssetExportPresetPassthrough
        } else {
            presetName = AVAssetExportPresetHighestQuality
        }

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: presetName
        ) else {
            throw CaptureError.videoCapture(
                "Could not create asset exporter."
            )
        }

        exporter.outputURL = output
        exporter.outputFileType = fileType
        exporter.shouldOptimizeForNetworkUse = false
        exporter.audioMix = audioMix

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

public enum CaptureExportMode: String, Sendable, Codable, Hashable {
    case passthrough
    case rendering
}

public enum CaptureSessionProgress: Sendable, Codable, Hashable {
    case recordingStopped(
        durationSeconds: TimeInterval
    )
    case exportStarted(
        mode: CaptureExportMode
    )
    case exportFinished(
        mode: CaptureExportMode
    )
}

public typealias CaptureSessionProgressHandler =
    @Sendable (CaptureSessionProgress) async -> Void
