public protocol CaptureDeviceProvider: Sendable {
    func displays() async throws -> [CaptureDevice]
    func audioInputs() async throws -> [CaptureDevice]
}

public struct StaticCaptureDeviceProvider: CaptureDeviceProvider {
    public let displayDevices: [CaptureDevice]
    public let audioInputDevices: [CaptureDevice]

    public init(
        displays: [CaptureDevice] = [],
        audioInputs: [CaptureDevice] = []
    ) {
        self.displayDevices = displays
        self.audioInputDevices = audioInputs
    }

    public func displays() async throws -> [CaptureDevice] {
        displayDevices
    }

    public func audioInputs() async throws -> [CaptureDevice] {
        audioInputDevices
    }
}
