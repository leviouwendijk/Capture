import Foundation

public struct MacCaptureDeviceProvider: CaptureDeviceProvider {
    public init() {}

    public func displays() async throws -> [CaptureDevice] {
        try await ScreenCaptureDeviceList().devices()
    }

    public func videoInputs() async throws -> [CaptureDevice] {
        try CameraCaptureDeviceList().devices()
    }

    public func audioInputs() async throws -> [CaptureDevice] {
        try CoreAudioDeviceList().inputDevices()
    }
}
