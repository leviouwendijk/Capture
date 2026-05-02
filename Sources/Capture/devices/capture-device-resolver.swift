import Foundation

public struct CaptureResolvedDevices: Sendable, Codable, Hashable {
    public let display: CaptureDevice
    public let audioInput: CaptureDevice

    public init(
        display: CaptureDevice,
        audioInput: CaptureDevice
    ) {
        self.display = display
        self.audioInput = audioInput
    }
}

public struct CaptureDeviceResolver: Sendable {
    public let provider: any CaptureDeviceProvider

    public init(
        provider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) {
        self.provider = provider
    }

    public func resolve(
        configuration: CaptureConfiguration
    ) async throws -> CaptureResolvedDevices {
        let displays = try await provider.displays()
        let audioInputs = try await provider.audioInputs()

        return try CaptureResolvedDevices(
            display: resolveDisplay(
                configuration.display,
                in: displays
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

private extension CaptureDeviceResolver {
    func resolveDisplay(
        _ display: CaptureDisplay,
        in devices: [CaptureDevice]
    ) throws -> CaptureDevice {
        guard !devices.isEmpty else {
            throw CaptureError.noDevices(
                .display
            )
        }

        switch display {
        case .main:
            if let main = devices.first(
                where: { $0.name == "Main Display" }
            ) {
                return main
            }

            return devices[0]

        case .index(let index):
            guard devices.indices.contains(index) else {
                throw CaptureError.invalidDisplayIndex(
                    index
                )
            }

            return devices[index]

        case .displayIdentifier(let identifier):
            let value = String(
                identifier
            )

            guard let device = devices.first(
                where: { $0.id == value }
            ) else {
                throw CaptureError.deviceNotFound(
                    kind: .display,
                    value: value
                )
            }

            return device
        }
    }
}
// import Foundation

// public struct CaptureResolvedDevices: Sendable, Codable, Hashable {
//     public let display: CaptureDevice
//     public let audioInput: CaptureDevice

//     public init(
//         display: CaptureDevice,
//         audioInput: CaptureDevice
//     ) {
//         self.display = display
//         self.audioInput = audioInput
//     }
// }

// public struct CaptureDeviceResolver: Sendable {
//     public let provider: any CaptureDeviceProvider

//     public init(
//         provider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
//     ) {
//         self.provider = provider
//     }

//     public func resolve(
//         configuration: CaptureConfiguration
//     ) async throws -> CaptureResolvedDevices {
//         let displays = try await provider.displays()
//         let audioInputs = try await provider.audioInputs()

//         return try CaptureResolvedDevices(
//             display: resolveDisplay(
//                 configuration.display,
//                 in: displays
//             ),
//             audioInput: resolveAudioInput(
//                 configuration.audio.device,
//                 in: audioInputs
//             )
//         )
//     }
// }

// private extension CaptureDeviceResolver {
//     func resolveDisplay(
//         _ display: CaptureDisplay,
//         in devices: [CaptureDevice]
//     ) throws -> CaptureDevice {
//         guard !devices.isEmpty else {
//             throw CaptureError.noDevices(
//                 .display
//             )
//         }

//         switch display {
//         case .main:
//             if let main = devices.first(
//                 where: { $0.name == "Main Display" }
//             ) {
//                 return main
//             }

//             return devices[0]

//         case .index(let index):
//             guard devices.indices.contains(index) else {
//                 throw CaptureError.invalidDisplayIndex(
//                     index
//                 )
//             }

//             return devices[index]

//         case .displayIdentifier(let identifier):
//             let value = String(
//                 identifier
//             )

//             guard let device = devices.first(
//                 where: { $0.id == value }
//             ) else {
//                 throw CaptureError.deviceNotFound(
//                     kind: .display,
//                     value: value
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
