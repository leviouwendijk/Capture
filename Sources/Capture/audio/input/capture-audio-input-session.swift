import Foundation

public typealias CaptureAudioInputHandler = @Sendable (
    CaptureAudioInputBuffer
) throws -> Void

public final class CaptureAudioInputSession: @unchecked Sendable {
    public let audio: CaptureAudioOptions
    public let deviceProvider: any CaptureDeviceProvider

    private let handler: CaptureAudioInputHandler
    private let lock = NSLock()

    private var stream: CoreAudioInputStream?

    public init(
        audio: CaptureAudioOptions,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider(),
        handler: @escaping CaptureAudioInputHandler
    ) {
        self.audio = audio
        self.deviceProvider = deviceProvider
        self.handler = handler
    }

    public func start() async throws {
        let resolvedDevice = try await resolveAudioInput()

        let stream = CoreAudioInputStream(
            device: resolvedDevice,
            audio: audio,
            bufferHandler: handler
        )

        try install(
            stream
        )

        do {
            try stream.start()
        } catch {
            removeIfCurrent(
                stream
            )

            throw error
        }
    }

    public func stop() throws {
        try takeStream()?.stop()
    }

    public func cancel() {
        try? stop()
    }

    public func firstSampleHostTimeSeconds() -> TimeInterval? {
        currentStream()?.firstSampleHostTimeSeconds()
    }

    public func runUntilStopped(
        stopSignal: CaptureStopSignal
    ) async throws {
        try await start()

        do {
            await stopSignal.wait()

            try stop()
        } catch {
            cancel()

            throw error
        }
    }

    public func runUntilCancelled() async throws {
        try await start()

        do {
            try await withTaskCancellationHandler {
                while !Task.isCancelled {
                    try await Task.sleep(
                        nanoseconds: 250_000_000
                    )
                }
            } onCancel: {
                self.cancel()
            }

            try stop()
        } catch is CancellationError {
            cancel()
        } catch {
            cancel()

            throw error
        }
    }
}

private extension CaptureAudioInputSession {
    func install(
        _ stream: CoreAudioInputStream
    ) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard self.stream == nil else {
            throw CaptureError.audioCapture(
                "Audio input session is already running."
            )
        }

        self.stream = stream
    }

    func removeIfCurrent(
        _ stream: CoreAudioInputStream
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }

        if self.stream === stream {
            self.stream = nil
        }
    }

    func takeStream() -> CoreAudioInputStream? {
        lock.lock()
        defer {
            lock.unlock()
        }

        let capturedStream = stream

        stream = nil

        return capturedStream
    }

    func currentStream() -> CoreAudioInputStream? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return stream
    }

    func resolveAudioInput() async throws -> CaptureDevice {
        let devices = try await deviceProvider.audioInputs()

        guard !devices.isEmpty else {
            throw CaptureError.noDevices(
                .audio_input
            )
        }

        switch audio.device {
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
