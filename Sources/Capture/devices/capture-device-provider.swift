public protocol CaptureDeviceProvider: Sendable {
    func displays() async throws -> [CaptureDevice]
    func videoInputs() async throws -> [CaptureDevice]
    func audioInputs() async throws -> [CaptureDevice]
}

public struct StaticCaptureDeviceProvider: CaptureDeviceProvider {
    public let displayDevices: [CaptureDevice]
    public let videoInputDevices: [CaptureDevice]
    public let audioInputDevices: [CaptureDevice]

    public init(
        displays: [CaptureDevice] = [],
        videoInputs: [CaptureDevice] = [],
        audioInputs: [CaptureDevice] = []
    ) {
        self.displayDevices = displays
        self.videoInputDevices = videoInputs
        self.audioInputDevices = audioInputs
    }

    public func displays() async throws -> [CaptureDevice] {
        displayDevices
    }

    public func videoInputs() async throws -> [CaptureDevice] {
        videoInputDevices
    }

    public func audioInputs() async throws -> [CaptureDevice] {
        audioInputDevices
    }
}
