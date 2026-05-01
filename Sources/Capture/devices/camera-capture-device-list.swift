import AVFoundation
import CoreMedia
import Foundation

struct CameraCaptureDeviceList: Sendable {
    func devices() throws -> [CaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes(),
            mediaType: .video,
            position: .unspecified
        )
        .devices
        .map {
            cameraDevice(
                $0
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare(
                $1.name
            ) == .orderedAscending
        }
    }
}

private extension CameraCaptureDeviceList {
    func deviceTypes() -> [AVCaptureDevice.DeviceType] {
        [
            .builtInWideAngleCamera,
            .continuityCamera,
            .external,
        ]
    }

    func cameraDevice(
        _ device: AVCaptureDevice
    ) -> CaptureDevice {
        CaptureDevice(
            id: device.uniqueID,
            name: device.localizedName,
            kind: .video_input,
            detail: detail(
                for: device
            ),
            size: size(
                for: device
            )
        )
    }

    func detail(
        for device: AVCaptureDevice
    ) -> String? {
        [
            size(
                for: device
            )?.label,
            typeLabel(
                for: device.deviceType
            ),
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(
            separator: "    "
        )
    }

    func size(
        for device: AVCaptureDevice
    ) -> CaptureVideoSize? {
        let dimensions = CMVideoFormatDescriptionGetDimensions(
            device.activeFormat.formatDescription
        )

        guard dimensions.width > 0,
              dimensions.height > 0 else {
            return nil
        }

        return CaptureVideoSize(
            width: Int(
                dimensions.width
            ),
            height: Int(
                dimensions.height
            )
        )
    }

    func typeLabel(
        for type: AVCaptureDevice.DeviceType
    ) -> String {
        switch type {
        case .builtInWideAngleCamera:
            return "built-in wide-angle"

        case .continuityCamera:
            return "continuity camera"

        case .external:
            return "external"

        default:
            return type.rawValue
        }
    }
}
