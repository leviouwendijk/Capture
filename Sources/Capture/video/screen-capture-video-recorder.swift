import Foundation

public struct ScreenCaptureVideoRecorder: Sendable {
    public init() {}

    public func recordVideo(
        configuration: CaptureConfiguration,
        options: CaptureVideoRecordOptions,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureVideoRecordingResult {
        try await ScreenCaptureMediaRecorder().recordMedia(
            configuration: configuration,
            systemAudioOutput: nil,
            options: options,
            deviceProvider: deviceProvider
        ).video
    }

    public func recordVideoUntilStopped(
        configuration: CaptureConfiguration,
        stopSignal: CaptureStopSignal,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
    ) async throws -> CaptureVideoRecordingResult {
        try await ScreenCaptureMediaRecorder().recordMediaUntilStopped(
            configuration: configuration,
            systemAudioOutput: nil,
            stopSignal: stopSignal,
            deviceProvider: deviceProvider
        ).video
    }
}

// import AVFoundation
// import CoreGraphics
// import CoreMedia
// import Foundation
// import ScreenCaptureKit

// public struct ScreenCaptureVideoRecorder: Sendable {
//     public init() {}

//     public func recordVideo(
//         configuration: CaptureConfiguration,
//         options: CaptureVideoRecordOptions,
//         deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
//     ) async throws -> CaptureVideoRecordingResult {
//         try validateOutput(
//             configuration.output
//         )

//         try ensureScreenRecordingPermission()

//         let resolved = try await CaptureDeviceResolver(
//             provider: deviceProvider
//         ).resolve(
//             configuration: configuration
//         )

//         let content = try await SCShareableContent.excludingDesktopWindows(
//             false,
//             onScreenWindowsOnly: true
//         )

//         guard let display = content.displays.first(
//             where: {
//                 String(
//                     $0.displayID
//                 ) == resolved.display.id
//             }
//         ) else {
//             throw CaptureError.deviceNotFound(
//                 kind: .display,
//                 value: resolved.display.id
//             )
//         }

//         let resolvedVideo = try configuration.video.resolved(
//             displaySize: displaySize(
//                 for: display
//             )
//         )

//         let filter = SCContentFilter(
//             display: display,
//             excludingWindows: []
//         )

//         let streamConfiguration = makeStreamConfiguration(
//             video: resolvedVideo
//         )

//         let writer = try ScreenCaptureVideoWriter(
//             output: configuration.output,
//             container: configuration.container,
//             video: resolvedVideo
//         )

//         let streamOutput = ScreenCaptureVideoStreamOutput(
//             writer: writer
//         )

//         let stream = SCStream(
//             filter: filter,
//             configuration: streamConfiguration,
//             delegate: streamOutput
//         )

//         try stream.addStreamOutput(
//             streamOutput,
//             type: .screen,
//             sampleHandlerQueue: streamOutput.queue
//         )

//         var streamDidStart = false
//         let startedAt = Date()
//         let startedHostTimeSeconds = CaptureClock.hostTimeSeconds()

//         do {
//             try await stream.startCapture()
//             streamDidStart = true

//             try await Task.sleep(
//                 nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000
//             )

//             try await stopStreamAllowingAlreadyStopped(
//                 stream
//             )
//             streamDidStart = false

//             let recordedSeconds = Date().timeIntervalSince(
//                 startedAt
//             )
//             let frameCount = try await writer.finish(
//                 diagnostics: streamOutput.diagnostics(
//                     requestedFramesPerSecond: resolvedVideo.fps,
//                     recordedSeconds: recordedSeconds,
//                     finishedFrameCount: nil
//                 ).summary
//             )
//             let diagnostics = streamOutput.diagnostics(
//                 requestedFramesPerSecond: resolvedVideo.fps,
//                 recordedSeconds: recordedSeconds,
//                 finishedFrameCount: frameCount
//             )

//             return CaptureVideoRecordingResult(
//                 output: configuration.output,
//                 display: resolved.display,
//                 durationSeconds: max(
//                     0,
//                     Int(
//                         recordedSeconds.rounded()
//                     )
//                 ),
//                 frameCount: frameCount,
//                 video: resolvedVideo,
//                 diagnostics: diagnostics,
//                 startedAt: startedAt,
//                 startedHostTimeSeconds: startedHostTimeSeconds,
//                 firstSampleAt: streamOutput.firstCompleteSampleAt(),
//                 firstPresentationTimeSeconds: streamOutput.firstCompleteFramePresentationTimeSeconds()
//             )
//         } catch {
//             if streamDidStart {
//                 try? await stopStreamAllowingAlreadyStopped(
//                     stream
//                 )
//             }

//             writer.cancel()
//             throw error
//         }
//     }

//     public func recordVideoUntilStopped(
//         configuration: CaptureConfiguration,
//         stopSignal: CaptureStopSignal,
//         deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider()
//     ) async throws -> CaptureVideoRecordingResult {
//         try validateOutput(
//             configuration.output
//         )

//         try ensureScreenRecordingPermission()

//         let resolved = try await CaptureDeviceResolver(
//             provider: deviceProvider
//         ).resolve(
//             configuration: configuration
//         )

//         let content = try await SCShareableContent.excludingDesktopWindows(
//             false,
//             onScreenWindowsOnly: true
//         )

//         guard let display = content.displays.first(
//             where: {
//                 String(
//                     $0.displayID
//                 ) == resolved.display.id
//             }
//         ) else {
//             throw CaptureError.deviceNotFound(
//                 kind: .display,
//                 value: resolved.display.id
//             )
//         }

//         let resolvedVideo = try configuration.video.resolved(
//             displaySize: displaySize(
//                 for: display
//             )
//         )

//         let filter = SCContentFilter(
//             display: display,
//             excludingWindows: []
//         )

//         let streamConfiguration = makeStreamConfiguration(
//             video: resolvedVideo
//         )

//         let writer = try ScreenCaptureVideoWriter(
//             output: configuration.output,
//             container: configuration.container,
//             video: resolvedVideo
//         )

//         let streamOutput = ScreenCaptureVideoStreamOutput(
//             writer: writer,
//             stopSignal: stopSignal
//         )

//         let stream = SCStream(
//             filter: filter,
//             configuration: streamConfiguration,
//             delegate: streamOutput
//         )

//         try stream.addStreamOutput(
//             streamOutput,
//             type: .screen,
//             sampleHandlerQueue: streamOutput.queue
//         )

//         let startedAt = Date()
//         let startedHostTimeSeconds = CaptureClock.hostTimeSeconds()
//         var streamDidStart = false

//         do {
//             try await stream.startCapture()
//             streamDidStart = true

//             await stopSignal.wait()

//             try await stopStreamAllowingAlreadyStopped(
//                 stream
//             )
//             streamDidStart = false

//             let recordedSeconds = Date().timeIntervalSince(
//                 startedAt
//             )
//             let frameCount = try await writer.finish(
//                 diagnostics: streamOutput.diagnostics(
//                     requestedFramesPerSecond: resolvedVideo.fps,
//                     recordedSeconds: recordedSeconds,
//                     finishedFrameCount: nil
//                 ).summary
//             )
//             let diagnostics = streamOutput.diagnostics(
//                 requestedFramesPerSecond: resolvedVideo.fps,
//                 recordedSeconds: recordedSeconds,
//                 finishedFrameCount: frameCount
//             )

//             return CaptureVideoRecordingResult(
//                 output: configuration.output,
//                 display: resolved.display,
//                 durationSeconds: max(
//                     0,
//                     Int(
//                         recordedSeconds.rounded()
//                     )
//                 ),
//                 frameCount: frameCount,
//                 video: resolvedVideo,
//                 diagnostics: diagnostics,
//                 startedAt: startedAt,
//                 startedHostTimeSeconds: startedHostTimeSeconds,
//                 firstSampleAt: streamOutput.firstCompleteSampleAt(),
//                 firstPresentationTimeSeconds: streamOutput.firstCompleteFramePresentationTimeSeconds()
//             )
//         } catch {
//             if streamDidStart {
//                 try? await stopStreamAllowingAlreadyStopped(
//                     stream
//                 )
//             }

//             writer.cancel()
//             throw error
//         }
//     }
// }

// internal extension ScreenCaptureVideoRecorder {
//     func validateOutput(
//         _ output: URL
//     ) throws {
//         let ext = output.pathExtension.lowercased()

//         guard ext == "mov" || ext == "mp4" else {
//             throw CaptureError.videoCapture(
//                 "Video-only capture currently writes .mov or .mp4 output."
//             )
//         }
//     }

//     func ensureScreenRecordingPermission() throws {
//         guard CGPreflightScreenCaptureAccess()
//                 || CGRequestScreenCaptureAccess() else {
//             throw CaptureError.videoCapture(
//                 "Screen Recording permission is not granted to this process. Grant it to the terminal host app, then fully quit and reopen that app."
//             )
//         }
//     }

//     func displaySize(
//         for display: SCDisplay
//     ) -> CaptureVideoSize {
//         CaptureVideoSize(
//             width: display.width,
//             height: display.height
//         )
//     }

//     func makeStreamConfiguration(
//         video: CaptureResolvedVideoOptions
//     ) -> SCStreamConfiguration {
//         let configuration = SCStreamConfiguration()
//         configuration.width = video.width
//         configuration.height = video.height
//         configuration.minimumFrameInterval = CMTime(
//             value: 1,
//             timescale: CMTimeScale(
//                 video.fps
//             )
//         )
//         configuration.queueDepth = 5
//         configuration.showsCursor = video.cursor
//         configuration.capturesAudio = false

//         return configuration
//     }

//     func stopStreamAllowingAlreadyStopped(
//         _ stream: SCStream
//     ) async throws {
//         do {
//             try await stream.stopCapture()
//         } catch {
//             guard isAlreadyStoppedStreamError(
//                 error
//             ) else {
//                 throw error
//             }
//         }
//     }

//     func isAlreadyStoppedStreamError(
//         _ error: Error
//     ) -> Bool {
//         let message = (error as NSError).localizedDescription

//         return message.localizedCaseInsensitiveContains(
//             "already stopped"
//         )
//     }
// }
