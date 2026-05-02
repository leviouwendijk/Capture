import Foundation

public struct CaptureResolvedCameraDevices: Sendable, Codable, Hashable {
    public let videoInput: CaptureDevice
    public let audioInput: CaptureDevice

    public init(
        videoInput: CaptureDevice,
        audioInput: CaptureDevice
    ) {
        self.videoInput = videoInput
        self.audioInput = audioInput
    }
}

public struct CameraCaptureDeviceResolver: Sendable {
    public let provider: any CaptureDeviceProvider

    public init(
        provider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) {
        self.provider = provider
    }

    public func resolve(
        configuration: CaptureCameraConfiguration
    ) async throws -> CaptureResolvedCameraDevices {
        let videoInputs = try await provider.videoInputs()
        let audioInputs = try await provider.audioInputs()

        return try CaptureResolvedCameraDevices(
            videoInput: resolveVideoInput(
                configuration.camera,
                in: videoInputs
            ),
            audioInput: CaptureAudioDeviceResolver(
                provider: provider
            ).resolve(
                configuration.audio.device,
                in: audioInputs
            )
        )
    }
}

private extension CameraCaptureDeviceResolver {
    func resolveVideoInput(
        _ videoInput: CaptureVideoInput,
        in devices: [CaptureDevice]
    ) throws -> CaptureDevice {
        guard !devices.isEmpty else {
            throw CaptureError.noDevices(
                .video_input
            )
        }

        switch videoInput {
        case .systemDefault:
            return devices[0]

        case .name(let name):
            if let exact = devices.first(
                where: {
                    $0.name == name
                        || $0.id == name
                }
            ) {
                return exact
            }

            if let caseInsensitive = devices.first(
                where: {
                    $0.name.localizedCaseInsensitiveCompare(
                        name
                    ) == .orderedSame
                }
            ) {
                return caseInsensitive
            }

            throw CaptureError.deviceNotFound(
                kind: .video_input,
                value: name
            )

        case .identifier(let identifier):
            guard let device = devices.first(
                where: { $0.id == identifier }
            ) else {
                throw CaptureError.deviceNotFound(
                    kind: .video_input,
                    value: identifier
                )
            }

            return device
        }
    }
}
// import Foundation

// public struct CaptureResolvedCameraDevices: Sendable, Codable, Hashable {
//     public let videoInput: CaptureDevice
//     public let audioInput: CaptureDevice

//     public init(
//         videoInput: CaptureDevice,
//         audioInput: CaptureDevice
//     ) {
//         self.videoInput = videoInput
//         self.audioInput = audioInput
//     }
// }

// public struct CameraCaptureDeviceResolver: Sendable {
//     public let provider: any CaptureDeviceProvider

//     public init(
//         provider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
//     ) {
//         self.provider = provider
//     }

//     public func resolve(
//         configuration: CaptureCameraConfiguration
//     ) async throws -> CaptureResolvedCameraDevices {
//         let videoInputs = try await provider.videoInputs()
//         let audioInputs = try await provider.audioInputs()

//         return try CaptureResolvedCameraDevices(
//             videoInput: resolveVideoInput(
//                 configuration.camera,
//                 in: videoInputs
//             ),
//             audioInput: resolveAudioInput(
//                 configuration.audio.device,
//                 in: audioInputs
//             )
//         )
//     }
// }

// private extension CameraCaptureDeviceResolver {
//     func resolveVideoInput(
//         _ videoInput: CaptureVideoInput,
//         in devices: [CaptureDevice]
//     ) throws -> CaptureDevice {
//         guard !devices.isEmpty else {
//             throw CaptureError.noDevices(
//                 .video_input
//             )
//         }

//         switch videoInput {
//         case .systemDefault:
//             return devices[0]

//         case .name(let name):
//             if let exact = devices.first(
//                 where: {
//                     $0.name == name
//                         || $0.id == name
//                 }
//             ) {
//                 return exact
//             }

//             if let caseInsensitive = devices.first(
//                 where: {
//                     $0.name.localizedCaseInsensitiveCompare(
//                         name
//                     ) == .orderedSame
//                 }
//             ) {
//                 return caseInsensitive
//             }

//             throw CaptureError.deviceNotFound(
//                 kind: .video_input,
//                 value: name
//             )

//         case .identifier(let identifier):
//             guard let device = devices.first(
//                 where: { $0.id == identifier }
//             ) else {
//                 throw CaptureError.deviceNotFound(
//                     kind: .video_input,
//                     value: identifier
//                 )
//             }

//             return device
//         }
//     }

//     func resolveAudioInput(
//         _ audioInput: CaptureAudioDevice,
//         in devices: [CaptureDevice]
//     ) throws -> CaptureDevice {
//         guard !devices.isEmpty else {
//             throw CaptureError.noDevices(
//                 .audio_input
//             )
//         }

//         switch audioInput {
//         case .systemDefault:
//             return devices[0]

//         case .name(let name):
//             if let exact = devices.first(
//                 where: {
//                     $0.name == name
//                         || $0.id == name
//                 }
//             ) {
//                 return exact
//             }

//             if let caseInsensitive = devices.first(
//                 where: {
//                     $0.name.localizedCaseInsensitiveCompare(
//                         name
//                     ) == .orderedSame
//                 }
//             ) {
//                 return caseInsensitive
//             }

//             throw CaptureError.deviceNotFound(
//                 kind: .audio_input,
//                 value: name
//             )

//         case .identifier(let identifier):
//             guard let device = devices.first(
//                 where: { $0.id == identifier }
//             ) else {
//                 throw CaptureError.deviceNotFound(
//                     kind: .audio_input,
//                     value: identifier
//                 )
//             }

//             return device
//         }
//     }
// }
