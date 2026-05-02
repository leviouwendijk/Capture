import Capture
import Foundation

internal func audioName(
    _ audio: CaptureAudioOptions
) -> String {
    switch audio.device {
    case .systemDefault:
        return "default"

    case .name(let name):
        return name

    case .identifier(let identifier):
        return identifier
    }
}

internal func cameraName(
    _ camera: CaptureVideoInput
) -> String {
    switch camera {
    case .systemDefault:
        return "default"

    case .name(let name):
        return name

    case .identifier(let identifier):
        return identifier
    }
}
