import Foundation

public enum CaptureCompositionSource: String, Sendable, Codable, Hashable, CaseIterable {
    case screen
    case camera
}

public enum CaptureCompositionPlacement: Sendable, Codable, Hashable {
    case fill
    case fit
    case overlay(CaptureOverlayPlacement)
    case sideBySide(CaptureSideBySidePlacement)
}

public struct CaptureCompositionLayout: Sendable, Codable, Hashable {
    public let layers: [CaptureCompositionLayer]

    public init(
        layers: [CaptureCompositionLayer]
    ) throws {
        guard !layers.isEmpty else {
            throw CaptureError.videoCapture(
                "Composition layout must contain at least one layer."
            )
        }

        self.layers = layers.sorted {
            $0.zIndex < $1.zIndex
        }
    }
}

public struct CaptureCompositionLayer: Sendable, Codable, Hashable {
    public let source: CaptureCompositionSource
    public let placement: CaptureCompositionPlacement
    public let opacity: Double
    public let zIndex: Int

    public init(
        source: CaptureCompositionSource,
        placement: CaptureCompositionPlacement,
        opacity: Double = 1.0,
        zIndex: Int
    ) throws {
        guard opacity.isFinite,
              opacity >= 0,
              opacity <= 1 else {
            throw CaptureError.videoCapture(
                "Invalid composition layer opacity: \(opacity)."
            )
        }

        self.source = source
        self.placement = placement
        self.opacity = opacity
        self.zIndex = zIndex
    }
}

public struct CaptureOverlayPlacement: Sendable, Codable, Hashable {
    public let widthRatio: Double
    public let horizontal: CaptureHorizontalPlacement
    public let vertical: CaptureVerticalPlacement
    public let margin: Int

    public init(
        widthRatio: Double,
        horizontal: CaptureHorizontalPlacement,
        vertical: CaptureVerticalPlacement,
        margin: Int = 32
    ) throws {
        guard widthRatio.isFinite,
              widthRatio > 0,
              widthRatio <= 1 else {
            throw CaptureError.videoCapture(
                "Invalid overlay width ratio: \(widthRatio)."
            )
        }

        guard margin >= 0 else {
            throw CaptureError.videoCapture(
                "Invalid overlay margin: \(margin)."
            )
        }

        self.widthRatio = widthRatio
        self.horizontal = horizontal
        self.vertical = vertical
        self.margin = margin
    }
}

public struct CaptureSideBySidePlacement: Sendable, Codable, Hashable {
    public let region: CaptureSideBySideRegion
    public let gap: Int

    public init(
        region: CaptureSideBySideRegion,
        gap: Int = 24
    ) throws {
        guard gap >= 0 else {
            throw CaptureError.videoCapture(
                "Invalid side-by-side gap: \(gap)."
            )
        }

        self.region = region
        self.gap = gap
    }
}

public enum CaptureHorizontalPlacement: String, Sendable, Codable, Hashable, CaseIterable {
    case left
    case center
    case right
}

public enum CaptureVerticalPlacement: String, Sendable, Codable, Hashable, CaseIterable {
    case top
    case middle
    case bottom
}

public enum CaptureSideBySideRegion: String, Sendable, Codable, Hashable, CaseIterable {
    case left
    case right
    case top
    case bottom
}
