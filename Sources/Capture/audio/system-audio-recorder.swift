// import AVFoundation
// import CoreGraphics
import Foundation
import ScreenCaptureKit

public struct ScreenCaptureSystemAudioRecorder: Sendable {
    public init() {}

    public func recordSystemAudioUntilStopped(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureSystemAudioRecordingResult {
        guard configuration.systemAudio.enabled else {
            throw CaptureError.audioCapture(
                "System audio capture is not enabled."
            )
        }

        try ensureScreenRecordingPermission()

        let resolved = try await CaptureDeviceResolver(
            provider: deviceProvider
        ).resolve(
            configuration: configuration
        )

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first(
            where: {
                String(
                    $0.displayID
                ) == resolved.display.id
            }
        ) else {
            throw CaptureError.deviceNotFound(
                kind: .display,
                value: resolved.display.id
            )
        }

        let filter = SCContentFilter(
            display: display,
            excludingWindows: []
        )

        let streamConfiguration = makeStreamConfiguration(
            systemAudio: configuration.systemAudio
        )

        let writer = try ScreenCaptureSystemAudioWriter(
            output: configuration.output,
            systemAudio: configuration.systemAudio
        )

        let streamOutput = ScreenCaptureSystemAudioStreamOutput(
            writer: writer
        )

        let stream = SCStream(
            filter: filter,
            configuration: streamConfiguration,
            delegate: streamOutput
        )

        try stream.addStreamOutput(
            streamOutput,
            type: .audio,
            sampleHandlerQueue: streamOutput.queue
        )

        let startedAt = Date()
        let startedHostTimeSeconds = CaptureClock.hostTimeSeconds()
        var streamDidStart = false

        do {
            try await stream.startCapture()
            streamDidStart = true

            await stopSignal.wait()

            try await stopStreamAllowingAlreadyStopped(
                stream
            )
            streamDidStart = false

            let duration = Date().timeIntervalSince(
                startedAt
            )

            let finishResult = try await writer.finish()

            return CaptureSystemAudioRecordingResult(
                output: configuration.output,
                durationSeconds: max(
                    0,
                    Int(
                        duration.rounded()
                    )
                ),
                sampleBufferCount: finishResult.sampleBufferCount,
                startedAt: startedAt,
                startedHostTimeSeconds: startedHostTimeSeconds,
                firstSampleAt: finishResult.firstSampleAt,
                firstPresentationTimeSeconds: finishResult.firstPresentationTimeSeconds
            )
        } catch {
            if streamDidStart {
                try? await stopStreamAllowingAlreadyStopped(
                    stream
                )
            }

            writer.cancel()
            throw error
        }
    }
}

internal extension ScreenCaptureSystemAudioRecorder {
    func ensureScreenRecordingPermission() throws {
        guard CGPreflightScreenCaptureAccess()
                || CGRequestScreenCaptureAccess() else {
            throw CaptureError.audioCapture(
                "Screen Recording permission is not granted to this process. Grant it to the terminal host app, then fully quit and reopen that app."
            )
        }
    }

    func makeStreamConfiguration(
        systemAudio: CaptureSystemAudioOptions
    ) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.sampleRate = systemAudio.sampleRate
        configuration.channelCount = systemAudio.channelCount
        configuration.excludesCurrentProcessAudio = systemAudio.excludesCurrentProcessAudio

        return configuration
    }

    func stopStreamAllowingAlreadyStopped(
        _ stream: SCStream
    ) async throws {
        do {
            try await stream.stopCapture()
        } catch {
            let message = (error as NSError).localizedDescription

            guard message.localizedCaseInsensitiveContains(
                "already stopped"
            ) else {
                throw error
            }
        }
    }
}
