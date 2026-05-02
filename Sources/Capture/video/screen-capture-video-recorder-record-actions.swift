import Foundation

public extension ScreenCaptureVideoRecorder {
    var record: ScreenCaptureVideoRecordActions {
        ScreenCaptureVideoRecordActions(
            recorder: self
        )
    }
}

public struct ScreenCaptureVideoRecordActions: Sendable {
    public let recorder: ScreenCaptureVideoRecorder

    public init(
        recorder: ScreenCaptureVideoRecorder
    ) {
        self.recorder = recorder
    }

    public func duration(
        _ duration: CaptureRecordDuration,
        configuration: CaptureConfiguration,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureVideoRecordingResult {
        try await recorder.recordVideo(
            configuration: configuration,
            options: CaptureVideoRecordOptions(
                duration: duration
            ),
            deviceProvider: deviceProvider
        )
    }

    public func live(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureVideoRecordingResult {
        try await recorder.recordVideoUntilStopped(
            configuration: configuration,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        )
    }

    public func mode(
        _ mode: CaptureRecordMode,
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureVideoRecordingResult {
        switch mode {
        case .live:
            return try await live(
                configuration: configuration,
                stopSignal: stopSignal,
                deviceProvider: deviceProvider
            )

        case .duration(let duration):
            return try await self.duration(
                duration,
                configuration: configuration,
                deviceProvider: deviceProvider
            )
        }
    }
}
