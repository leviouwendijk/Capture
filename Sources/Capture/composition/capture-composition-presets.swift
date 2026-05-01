import Foundation

public extension CaptureCompositionLayout {
    static func screenWithCameraOverlay(
        cameraWidthRatio: Double = 0.24,
        horizontal: CaptureHorizontalPlacement = .right,
        vertical: CaptureVerticalPlacement = .bottom,
        margin: Int = 32
    ) throws -> CaptureCompositionLayout {
        try CaptureCompositionLayout(
            layers: [
                CaptureCompositionLayer(
                    source: .screen,
                    placement: .fill,
                    zIndex: 0
                ),
                CaptureCompositionLayer(
                    source: .camera,
                    placement: .overlay(
                        CaptureOverlayPlacement(
                            widthRatio: cameraWidthRatio,
                            horizontal: horizontal,
                            vertical: vertical,
                            margin: margin
                        )
                    ),
                    zIndex: 1
                ),
            ]
        )
    }

    static func cameraWithScreenOverlay(
        screenWidthRatio: Double = 0.24,
        horizontal: CaptureHorizontalPlacement = .right,
        vertical: CaptureVerticalPlacement = .bottom,
        margin: Int = 32
    ) throws -> CaptureCompositionLayout {
        try CaptureCompositionLayout(
            layers: [
                CaptureCompositionLayer(
                    source: .camera,
                    placement: .fill,
                    zIndex: 0
                ),
                CaptureCompositionLayer(
                    source: .screen,
                    placement: .overlay(
                        CaptureOverlayPlacement(
                            widthRatio: screenWidthRatio,
                            horizontal: horizontal,
                            vertical: vertical,
                            margin: margin
                        )
                    ),
                    zIndex: 1
                ),
            ]
        )
    }

    static func screenAndCameraSideBySide(
        gap: Int = 24
    ) throws -> CaptureCompositionLayout {
        try CaptureCompositionLayout(
            layers: [
                CaptureCompositionLayer(
                    source: .screen,
                    placement: .sideBySide(
                        CaptureSideBySidePlacement(
                            region: .left,
                            gap: gap
                        )
                    ),
                    zIndex: 0
                ),
                CaptureCompositionLayer(
                    source: .camera,
                    placement: .sideBySide(
                        CaptureSideBySidePlacement(
                            region: .right,
                            gap: gap
                        )
                    ),
                    zIndex: 1
                ),
            ]
        )
    }
}
