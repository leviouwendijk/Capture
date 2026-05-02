import Capture
import Foundation

internal struct CaptureLiveAudioSmokeOptions: Sendable {
    internal let audio: CaptureAudioOptions
    internal let durationSeconds: Int

    internal init(
        audio: CaptureAudioOptions,
        durationSeconds: Int
    ) throws {
        guard durationSeconds > 0 else {
            throw CaptureError.invalidDurationSeconds(
                durationSeconds
            )
        }

        self.audio = audio
        self.durationSeconds = durationSeconds
    }
}

internal extension CaptureCLI {
    static func runLiveAudioSmoke(
        options: CaptureLiveAudioSmokeOptions
    ) async throws {
        let counter = LiveAudioSmokeCounter()

        let session = CaptureAudioInputSession(
            audio: options.audio
        ) { buffer in
            counter.record(
                buffer
            )
        }

        let started = try await session.start()

        print(
            "live audio: started"
        )
        print(
            "  input       \(started.device.name)"
        )
        print(
            "  sample rate \(started.sampleRate) Hz"
        )
        print(
            "  channels    \(started.channelCount)"
        )
        print(
            "  duration    \(options.durationSeconds)s"
        )

        do {
            try await Task.sleep(
                nanoseconds: UInt64(
                    options.durationSeconds
                ) * 1_000_000_000
            )

            try session.stop()
        } catch {
            session.cancel()

            throw error
        }

        let snapshot = counter.snapshot()

        print(
            "live audio: stopped"
        )
        print(
            "  buffers     \(snapshot.bufferCount)"
        )
        print(
            "  frames      \(snapshot.frameCount)"
        )
        print(
            "  first host  \(snapshot.firstHostTimeDescription)"
        )

        guard snapshot.bufferCount > 0,
              snapshot.frameCount > 0 else {
            throw CaptureError.audioCapture(
                "Live audio smoke captured no buffers."
            )
        }
    }
}

private final class LiveAudioSmokeCounter: @unchecked Sendable {
    private let lock = NSLock()

    private var bufferCount = 0
    private var frameCount = 0
    private var firstHostTimeSeconds: TimeInterval?

    fileprivate func record(
        _ buffer: CaptureAudioInputBuffer
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }

        bufferCount += 1
        frameCount += buffer.frameCount

        if firstHostTimeSeconds == nil {
            firstHostTimeSeconds = buffer.hostTimeSeconds
        }
    }

    fileprivate func snapshot() -> LiveAudioSmokeSnapshot {
        lock.lock()
        defer {
            lock.unlock()
        }

        return LiveAudioSmokeSnapshot(
            bufferCount: bufferCount,
            frameCount: frameCount,
            firstHostTimeSeconds: firstHostTimeSeconds
        )
    }
}

private struct LiveAudioSmokeSnapshot {
    let bufferCount: Int
    let frameCount: Int
    let firstHostTimeSeconds: TimeInterval?

    var firstHostTimeDescription: String {
        guard let firstHostTimeSeconds else {
            return "none"
        }

        return String(
            format: "%.6f",
            firstHostTimeSeconds
        )
    }
}
