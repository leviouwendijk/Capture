import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation

public struct CaptureCompositionVideoRenderer {
    public init() {}

    internal func render(
        inputs: [CaptureCompositionVideoInput],
        layout: CaptureCompositionLayout,
        video: CaptureResolvedVideoOptions,
        output: URL,
        container: CaptureContainer
    ) async throws -> CaptureCompositionVideoRenderingResult {
        try prepareOutput(
            output
        )

        let composition = AVMutableComposition()
        let loadedInputs = try await loadInputs(
            inputs,
            into: composition
        )

        guard !loadedInputs.isEmpty else {
            throw CaptureError.videoCapture(
                "Composition has no video inputs."
            )
        }

        let duration = compositionDuration(
            for: loadedInputs
        )

        guard CMTimeCompare(
            duration,
            .zero
        ) > 0 else {
            throw CaptureError.videoCapture(
                "Composition duration is empty."
            )
        }

        let videoComposition = try makeVideoComposition(
            loadedInputs: loadedInputs,
            layout: layout,
            video: video,
            duration: duration
        )

        try await export(
            composition: composition,
            videoComposition: videoComposition,
            output: output,
            container: container
        )

        return CaptureCompositionVideoRenderingResult(
            output: output,
            durationSeconds: max(
                0,
                Int(
                    CMTimeGetSeconds(
                        duration
                    ).rounded()
                )
            ),
            video: video
        )
    }
}

private struct LoadedCompositionVideoInput {
    let source: CaptureCompositionSource
    let asset: AVURLAsset
    let sourceTrack: AVAssetTrack
    let compositionTrack: AVMutableCompositionTrack
    let naturalSize: CGSize
    let sourceStart: CMTime
    let destinationStart: CMTime
    let insertedDuration: CMTime
}

private extension CaptureCompositionVideoRenderer {
    func prepareOutput(
        _ output: URL
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
    }

    func loadInputs(
        _ inputs: [CaptureCompositionVideoInput],
        into composition: AVMutableComposition
    ) async throws -> [LoadedCompositionVideoInput] {
        var loadedInputs: [LoadedCompositionVideoInput] = []

        for input in inputs {
            let asset = AVURLAsset(
                url: input.url
            )

            let sourceTracks = try await asset.loadTracks(
                withMediaType: .video
            )

            guard let sourceTrack = sourceTracks.first else {
                throw CaptureError.videoCapture(
                    "Could not find \(input.source.rawValue) video track in \(input.url.lastPathComponent)."
                )
            }

            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw CaptureError.videoCapture(
                    "Could not create composition track for \(input.source.rawValue)."
                )
            }

            let duration = try await asset.load(
                .duration
            )
            let naturalSize = try await sourceTrack.load(
                .naturalSize
            )

            let timing = timelineTiming(
                duration: duration,
                startOffsetSeconds: input.startOffsetSeconds
            )

            guard CMTimeCompare(
                timing.insertedDuration,
                .zero
            ) > 0 else {
                continue
            }

            try compositionTrack.insertTimeRange(
                CMTimeRange(
                    start: timing.sourceStart,
                    duration: timing.insertedDuration
                ),
                of: sourceTrack,
                at: timing.destinationStart
            )

            loadedInputs.append(
                LoadedCompositionVideoInput(
                    source: input.source,
                    asset: asset,
                    sourceTrack: sourceTrack,
                    compositionTrack: compositionTrack,
                    naturalSize: naturalSize,
                    sourceStart: timing.sourceStart,
                    destinationStart: timing.destinationStart,
                    insertedDuration: timing.insertedDuration
                )
            )
        }

        return loadedInputs
    }

    func timelineTiming(
        duration: CMTime,
        startOffsetSeconds: TimeInterval
    ) -> (
        sourceStart: CMTime,
        destinationStart: CMTime,
        insertedDuration: CMTime
    ) {
        let preferredTimescale = CMTimeScale(
            max(
                duration.timescale,
                600
            )
        )

        let absoluteOffset = CMTime(
            seconds: abs(
                startOffsetSeconds
            ),
            preferredTimescale: preferredTimescale
        )

        if startOffsetSeconds < 0 {
            return (
                sourceStart: absoluteOffset,
                destinationStart: .zero,
                insertedDuration: CMTimeSubtract(
                    duration,
                    absoluteOffset
                )
            )
        }

        return (
            sourceStart: .zero,
            destinationStart: absoluteOffset,
            insertedDuration: duration
        )
    }

    func compositionDuration(
        for inputs: [LoadedCompositionVideoInput]
    ) -> CMTime {
        inputs
            .map {
                CMTimeAdd(
                    $0.destinationStart,
                    $0.insertedDuration
                )
            }
            .max {
                CMTimeCompare(
                    $0,
                    $1
                ) < 0
            } ?? .zero
    }

    func makeVideoComposition(
        loadedInputs: [LoadedCompositionVideoInput],
        layout: CaptureCompositionLayout,
        video: CaptureResolvedVideoOptions,
        duration: CMTime
    ) throws -> AVMutableVideoComposition {
        let instruction = AVMutableVideoCompositionInstruction()

        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: duration
        )

        let canvas = CGSize(
            width: video.width,
            height: video.height
        )

        let layerInstructions = layout.layers
            .sorted {
                $0.zIndex > $1.zIndex
            }
            .compactMap { layer -> AVMutableVideoCompositionLayerInstruction? in
                guard let loadedInput = loadedInputs.first(
                    where: { $0.source == layer.source }
                ) else {
                    return nil
                }

                let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: loadedInput.compositionTrack
                )

                layerInstruction.setTransform(
                    transform(
                        sourceSize: loadedInput.naturalSize,
                        canvasSize: canvas,
                        placement: layer.placement
                    ),
                    at: .zero
                )

                layerInstruction.setOpacity(
                    Float(
                        layer.opacity
                    ),
                    at: .zero
                )

                return layerInstruction
            }

        guard !layerInstructions.isEmpty else {
            throw CaptureError.videoCapture(
                "Composition layout did not match any captured video sources."
            )
        }

        instruction.layerInstructions = layerInstructions

        let videoComposition = AVMutableVideoComposition()

        videoComposition.renderSize = canvas
        videoComposition.frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(
                video.fps
            )
        )
        videoComposition.instructions = [
            instruction,
        ]

        return videoComposition
    }

    func transform(
        sourceSize: CGSize,
        canvasSize: CGSize,
        placement: CaptureCompositionPlacement
    ) -> CGAffineTransform {
        let rect: CGRect

        switch placement {
        case .fill:
            rect = aspectFillRect(
                sourceSize: sourceSize,
                targetRect: CGRect(
                    origin: .zero,
                    size: canvasSize
                )
            )

        case .fit:
            rect = aspectFitRect(
                sourceSize: sourceSize,
                targetRect: CGRect(
                    origin: .zero,
                    size: canvasSize
                )
            )

        case .overlay(let overlay):
            rect = overlayRect(
                sourceSize: sourceSize,
                canvasSize: canvasSize,
                overlay: overlay
            )

        case .sideBySide(let sideBySide):
            rect = aspectFitRect(
                sourceSize: sourceSize,
                targetRect: sideBySideRect(
                    canvasSize: canvasSize,
                    placement: sideBySide
                )
            )
        }

        let scaleX = rect.width / sourceSize.width
        let scaleY = rect.height / sourceSize.height

        return CGAffineTransform(
            translationX: rect.minX,
            y: rect.minY
        )
        .scaledBy(
            x: scaleX,
            y: scaleY
        )
    }

    func aspectFitRect(
        sourceSize: CGSize,
        targetRect: CGRect
    ) -> CGRect {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              targetRect.width > 0,
              targetRect.height > 0 else {
            return targetRect
        }

        let scale = min(
            targetRect.width / sourceSize.width,
            targetRect.height / sourceSize.height
        )

        let width = sourceSize.width * scale
        let height = sourceSize.height * scale

        return CGRect(
            x: targetRect.midX - width / 2,
            y: targetRect.midY - height / 2,
            width: width,
            height: height
        )
    }

    func aspectFillRect(
        sourceSize: CGSize,
        targetRect: CGRect
    ) -> CGRect {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              targetRect.width > 0,
              targetRect.height > 0 else {
            return targetRect
        }

        let scale = max(
            targetRect.width / sourceSize.width,
            targetRect.height / sourceSize.height
        )

        let width = sourceSize.width * scale
        let height = sourceSize.height * scale

        return CGRect(
            x: targetRect.midX - width / 2,
            y: targetRect.midY - height / 2,
            width: width,
            height: height
        )
    }

    func overlayRect(
        sourceSize: CGSize,
        canvasSize: CGSize,
        overlay: CaptureOverlayPlacement
    ) -> CGRect {
        let maxWidth = max(
            1,
            canvasSize.width - Double(
                overlay.margin * 2
            )
        )
        let maxHeight = max(
            1,
            canvasSize.height - Double(
                overlay.margin * 2
            )
        )

        let requestedWidth = min(
            maxWidth,
            canvasSize.width * overlay.widthRatio
        )

        let sourceAspect = sourceSize.height / max(
            1,
            sourceSize.width
        )

        var width = requestedWidth
        var height = width * sourceAspect

        if height > maxHeight {
            height = maxHeight
            width = height / max(
                sourceAspect,
                0.0001
            )
        }

        let x: Double

        switch overlay.horizontal {
        case .left:
            x = Double(
                overlay.margin
            )

        case .center:
            x = (canvasSize.width - width) / 2

        case .right:
            x = canvasSize.width - width - Double(
                overlay.margin
            )
        }

        let y: Double

        switch overlay.vertical {
        case .top:
            y = Double(
                overlay.margin
            )

        case .middle:
            y = (canvasSize.height - height) / 2

        case .bottom:
            y = canvasSize.height - height - Double(
                overlay.margin
            )
        }

        return CGRect(
            x: x,
            y: y,
            width: width,
            height: height
        )
    }

    func sideBySideRect(
        canvasSize: CGSize,
        placement: CaptureSideBySidePlacement
    ) -> CGRect {
        let gap = Double(
            placement.gap
        )

        switch placement.region {
        case .left:
            return CGRect(
                x: 0,
                y: 0,
                width: max(
                    1,
                    (canvasSize.width - gap) / 2
                ),
                height: canvasSize.height
            )

        case .right:
            return CGRect(
                x: (canvasSize.width + gap) / 2,
                y: 0,
                width: max(
                    1,
                    (canvasSize.width - gap) / 2
                ),
                height: canvasSize.height
            )

        case .top:
            return CGRect(
                x: 0,
                y: 0,
                width: canvasSize.width,
                height: max(
                    1,
                    (canvasSize.height - gap) / 2
                )
            )

        case .bottom:
            return CGRect(
                x: 0,
                y: (canvasSize.height + gap) / 2,
                width: canvasSize.width,
                height: max(
                    1,
                    (canvasSize.height - gap) / 2
                )
            )
        }
    }

    func export(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition,
        output: URL,
        container: CaptureContainer
    ) async throws {
        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw CaptureError.videoCapture(
                "Could not create composition video exporter."
            )
        }

        exporter.outputURL = output
        exporter.outputFileType = fileType(
            for: container
        )
        exporter.shouldOptimizeForNetworkUse = false
        exporter.videoComposition = videoComposition

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exporter.status == .completed else {
            throw exporter.error.map(Self.describe)
                .map(CaptureError.videoCapture)
                ?? CaptureError.videoCapture(
                    "Could not render composed video."
                )
        }
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

    static func describe(
        _ error: Error
    ) -> String {
        let nsError = error as NSError

        return "\(nsError.localizedDescription) domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)"
    }
}
