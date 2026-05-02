import Foundation

public struct CaptureAudioDeviceResolver: Sendable {
    public let provider: any CaptureDeviceProvider

    public init(
        provider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) {
        self.provider = provider
    }

    public func resolve(
        _ audioInput: CaptureAudioDevice
    ) async throws -> CaptureDevice {
        try await resolve(
            audioInput,
            in: provider.audioInputs()
        )
    }

    public func resolve(
        _ audioInput: CaptureAudioDevice,
        in devices: [CaptureDevice]
    ) throws -> CaptureDevice {
        guard !devices.isEmpty else {
            throw CaptureError.noDevices(
                .audio_input
            )
        }

        switch audioInput {
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
                kind: .audio_input,
                value: name
            )

        case .identifier(let identifier):
            guard let device = devices.first(
                where: { $0.id == identifier }
            ) else {
                throw CaptureError.deviceNotFound(
                    kind: .audio_input,
                    value: identifier
                )
            }

            return device
        }
    }
}
