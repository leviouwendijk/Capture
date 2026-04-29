import AVFoundation
import Foundation

internal struct CaptureAssetMuxer: Sendable {
    func mux(
        video: URL,
        audio: [CaptureMuxAudioInput],
        audioMix: CaptureAudioMixOptions,
        output: URL,
        container: CaptureContainer
    ) async throws {
        if audioMix.requiresAudioRendering {
            let mixedAudioOutput = try await renderMixedAudio(
                audio: audio,
                audioMix: audioMix
            )

            defer {
                try? FileManager.default.removeItem(
                    at: mixedAudioOutput.deletingLastPathComponent()
                )
            }

            try await muxPassthrough(
                video: video,
                audio: [
                    CaptureMuxAudioInput(
                        url: mixedAudioOutput,
                        role: .mixed,
                        gain: 1.0,
                        startOffsetSeconds: 0
                    ),
                ],
                output: output,
                container: container
            )
        } else {
            try await muxPassthrough(
                video: video,
                audio: audio,
                output: output,
                container: container
            )
        }
    }
}

internal extension CaptureAssetMuxer {
    func renderMixedAudio(
        audio: [CaptureMuxAudioInput],
        audioMix: CaptureAudioMixOptions
    ) async throws -> URL {
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "capture-audio-mix-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )

        let output = workingDirectory.appendingPathComponent(
            "mixed-audio.m4a"
        )

        let composition = AVMutableComposition()
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

        guard let renderedAudioMix = makeAudioMix(
            tracks: audioTracks,
            options: audioMix
        ) else {
            throw CaptureError.audioCapture(
                "Could not create rendered audio mix."
            )
        }

        try await exportAudioOnly(
            composition: composition,
            output: output,
            audioMix: renderedAudioMix
        )

        return output
    }

    func muxPassthrough(
        video: URL,
        audio: [CaptureMuxAudioInput],
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

        for audioInput in audio {
            _ = try await addAudioTrack(
                from: audioInput,
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

        try await exportPassthrough(
            composition: composition,
            output: output,
            fileType: fileType(
                for: container
            )
        )
    }

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

    func exportAudioOnly(
        composition: AVMutableComposition,
        output: URL,
        audioMix: AVMutableAudioMix
    ) async throws {
        if FileManager.default.fileExists(
            atPath: output.path
        ) {
            try FileManager.default.removeItem(
                at: output
            )
        }

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw CaptureError.audioCapture(
                "Could not create audio-only asset exporter."
            )
        }

        exporter.outputURL = output
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = false
        exporter.audioMix = audioMix

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exporter.status == .completed else {
            throw exporter.error.map(Self.describe)
                .map(CaptureError.audioCapture)
                ?? CaptureError.audioCapture(
                    "Could not render mixed audio."
                )
        }
    }

    func exportPassthrough(
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
