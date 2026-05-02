import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

internal struct ScreenCaptureMediaRecorder: Sendable {
    internal init() {}

    internal func recordMedia(
        configuration: CaptureConfiguration,
        systemAudioOutput: URL?,
        options: CaptureVideoRecordOptions,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureScreenMediaRecordingResult {
        let stopSignal = CaptureStopSignal()

        Task {
            try? await Task.sleep(
                nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000
            )

            stopSignal.stop()
        }

        return try await recordMediaUntilStopped(
            configuration: configuration,
            systemAudioOutput: systemAudioOutput,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        )
    }

    internal func recordMediaUntilStopped(
        configuration: CaptureConfiguration,
        systemAudioOutput: URL?,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureScreenMediaRecordingResult {
        try validateOutput(
            configuration.output
        )

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

        let resolvedVideo = try configuration.video.resolved(
            displaySize: displaySize(
                for: display
            )
        )

        let shouldCaptureSystemAudio = configuration.systemAudio.enabled
            && systemAudioOutput != nil

        let resolvedSystemAudioOutput = shouldCaptureSystemAudio
            ? systemAudioOutput
            : nil

        let filter = SCContentFilter(
            display: display,
            excludingWindows: []
        )

        let streamConfiguration = makeStreamConfiguration(
            video: resolvedVideo,
            systemAudio: shouldCaptureSystemAudio
                ? configuration.systemAudio
                : nil
        )

        let videoWriter = try ScreenCaptureVideoWriter(
            output: configuration.output,
            container: configuration.container,
            video: resolvedVideo
        )

        let systemAudioWriter: ScreenCaptureSystemAudioWriter?

        if let resolvedSystemAudioOutput {
            systemAudioWriter = try ScreenCaptureSystemAudioWriter(
                output: resolvedSystemAudioOutput,
                systemAudio: configuration.systemAudio
            )
        } else {
            systemAudioWriter = nil
        }

        let streamOutput = ScreenCaptureVideoStreamOutput(
            writer: videoWriter,
            systemAudioWriter: systemAudioWriter,
            stopSignal: stopSignal
        )

        let stream = SCStream(
            filter: filter,
            configuration: streamConfiguration,
            delegate: streamOutput
        )

        try stream.addStreamOutput(
            streamOutput,
            type: .screen,
            sampleHandlerQueue: streamOutput.queue
        )

        if systemAudioWriter != nil {
            try stream.addStreamOutput(
                streamOutput,
                type: .audio,
                sampleHandlerQueue: streamOutput.queue
            )
        }

        let startedAt = Date()
        let startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

        var streamDidStart = false
        var videoDidFinish = false
        var systemAudioDidFinish = systemAudioWriter == nil

        do {
            try await stream.startCapture()
            streamDidStart = true

            await stopSignal.wait()

            try await stopStreamAllowingAlreadyStopped(
                stream
            )
            streamDidStart = false

            let recordedSeconds = Date().timeIntervalSince(
                startedAt
            )

            let frameCount = try await videoWriter.finish(
                diagnostics: streamOutput.diagnostics(
                    requestedFramesPerSecond: resolvedVideo.fps,
                    recordedSeconds: recordedSeconds,
                    finishedFrameCount: nil
                ).summary
            )
            videoDidFinish = true

            let systemAudioFinishResult: ScreenCaptureSystemAudioWriterFinishResult?

            if let systemAudioWriter {
                systemAudioFinishResult = try await systemAudioWriter.finish()
                systemAudioDidFinish = true
            } else {
                systemAudioFinishResult = nil
            }

            let diagnostics = streamOutput.diagnostics(
                requestedFramesPerSecond: resolvedVideo.fps,
                recordedSeconds: recordedSeconds,
                finishedFrameCount: frameCount
            )

            let videoResult = CaptureVideoRecordingResult(
                output: configuration.output,
                display: resolved.display,
                durationSeconds: max(
                    0,
                    Int(
                        recordedSeconds.rounded()
                    )
                ),
                frameCount: frameCount,
                video: resolvedVideo,
                diagnostics: diagnostics,
                startedAt: startedAt,
                startedHostTimeSeconds: startedHostTimeSeconds,
                firstSampleAt: streamOutput.firstCompleteSampleAt(),
                firstPresentationTimeSeconds: streamOutput.firstCompleteFramePresentationTimeSeconds()
            )

            let systemAudioResult: CaptureSystemAudioRecordingResult?

            if let systemAudioFinishResult,
               let resolvedSystemAudioOutput {
                systemAudioResult = CaptureSystemAudioRecordingResult(
                    output: resolvedSystemAudioOutput,
                    durationSeconds: max(
                        0,
                        Int(
                            recordedSeconds.rounded()
                        )
                    ),
                    sampleBufferCount: systemAudioFinishResult.sampleBufferCount,
                    startedAt: startedAt,
                    startedHostTimeSeconds: startedHostTimeSeconds,
                    firstSampleAt: systemAudioFinishResult.firstSampleAt,
                    firstPresentationTimeSeconds: systemAudioFinishResult.firstPresentationTimeSeconds
                )
            } else {
                systemAudioResult = nil
            }

            return CaptureScreenMediaRecordingResult(
                video: videoResult,
                systemAudio: systemAudioResult
            )
        } catch {
            if streamDidStart {
                try? await stopStreamAllowingAlreadyStopped(
                    stream
                )
            }

            if !videoDidFinish {
                videoWriter.cancel()
            }

            if !systemAudioDidFinish {
                systemAudioWriter?.cancel()
            }

            throw error
        }
    }
}

private extension ScreenCaptureMediaRecorder {
    func validateOutput(
        _ output: URL
    ) throws {
        let ext = output.pathExtension.lowercased()

        guard ext == "mov" || ext == "mp4" else {
            throw CaptureError.videoCapture(
                "Video-only capture currently writes .mov or .mp4 output."
            )
        }
    }

    func ensureScreenRecordingPermission() throws {
        guard CGPreflightScreenCaptureAccess()
                || CGRequestScreenCaptureAccess() else {
            throw CaptureError.videoCapture(
                "Screen Recording permission is not granted to this process. Grant it to the terminal host app, then fully quit and reopen that app."
            )
        }
    }

    func displaySize(
        for display: SCDisplay
    ) -> CaptureVideoSize {
        CaptureVideoSize(
            width: display.width,
            height: display.height
        )
    }

    func makeStreamConfiguration(
        video: CaptureResolvedVideoOptions,
        systemAudio: CaptureSystemAudioOptions?
    ) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()

        configuration.width = video.width
        configuration.height = video.height
        configuration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(
                video.fps
            )
        )
        configuration.queueDepth = 5
        configuration.showsCursor = video.cursor

        if let systemAudio {
            configuration.capturesAudio = true
            configuration.sampleRate = systemAudio.sampleRate
            configuration.channelCount = systemAudio.channelCount
            configuration.excludesCurrentProcessAudio = systemAudio.excludesCurrentProcessAudio
        } else {
            configuration.capturesAudio = false
        }

        return configuration
    }

    func stopStreamAllowingAlreadyStopped(
        _ stream: SCStream
    ) async throws {
        do {
            try await stream.stopCapture()
        } catch {
            guard isAlreadyStoppedStreamError(
                error
            ) else {
                throw error
            }
        }
    }

    func isAlreadyStoppedStreamError(
        _ error: Error
    ) -> Bool {
        let message = (error as NSError).localizedDescription

        return message.localizedCaseInsensitiveContains(
            "already stopped"
        )
    }
}
