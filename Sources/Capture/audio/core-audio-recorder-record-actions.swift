import Foundation

public extension CoreAudioRecorder {
    var record: CoreAudioRecordActions {
        CoreAudioRecordActions(
            recorder: self
        )
    }
}

public struct CoreAudioRecordActions: Sendable {
    public let recorder: CoreAudioRecorder

    public init(
        recorder: CoreAudioRecorder
    ) {
        self.recorder = recorder
    }

    public func duration(
        _ duration: CaptureRecordDuration,
        configuration: CaptureConfiguration,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureAudioRecordingResult {
        try await recorder.recordAudio(
            configuration: configuration,
            options: CaptureAudioRecordOptions(
                duration: duration
            ),
            deviceProvider: deviceProvider
        )
    }

    public func live(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureAudioRecordingResult {
        try await recorder.recordAudioUntilStopped(
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
    ) async throws -> CaptureAudioRecordingResult {
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
