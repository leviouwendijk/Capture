import Foundation

public typealias CaptureAudioInputHandler = @Sendable (
    CaptureAudioInputBuffer
) throws -> Void

public final class CaptureAudioInputSession: @unchecked Sendable {
    public let audio: CaptureAudioOptions
    public let deviceProvider: any CaptureDeviceProvider

    private let handler: CaptureAudioInputHandler
    private let lock = NSLock()
    private let chainLock = NSLock()

    private var chain: Audio.Chain
    private var stream: CoreAudioInputStream?
    private var startResult: CaptureAudioInputStartResult?

    public init(
        audio: CaptureAudioOptions,
        deviceProvider: any CaptureDeviceProvider = MacCaptureDeviceProvider(),
        chain: Audio.Chain = .raw,
        handler: @escaping CaptureAudioInputHandler
    ) {
        self.audio = audio
        self.deviceProvider = deviceProvider
        self.chain = chain
        self.handler = handler
    }

    @discardableResult
    public func start() async throws -> CaptureAudioInputStartResult {
        try validateAudio()

        let resolvedDevice = try await CaptureAudioDeviceResolver(
            provider: deviceProvider
        ).resolve(
            audio.device
        )

        let stream = CoreAudioInputStream(
            device: resolvedDevice,
            audio: audio,
            bufferHandler: { buffer in
                try self.handle(
                    buffer
                )
            }
        )

        let result = CaptureAudioInputStartResult(
            device: resolvedDevice,
            sampleRate: audio.sampleRate,
            channelCount: audio.channel
        )

        try install(
            stream,
            result: result
        )

        do {
            try stream.start()

            return result
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

    public func currentStartResult() -> CaptureAudioInputStartResult? {
        currentResult()
    }

    public func firstSampleHostTimeSeconds() -> TimeInterval? {
        currentStream()?.firstSampleHostTimeSeconds()
    }

    @discardableResult
    public func runUntilStopped(
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureAudioInputStartResult {
        let result = try await start()

        do {
            await stopSignal.wait()

            try stop()

            return result
        } catch {
            cancel()

            throw error
        }
    }

    @discardableResult
    public func runUntilCancelled() async throws -> CaptureAudioInputStartResult {
        let result = try await start()

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

            return result
        } catch is CancellationError {
            cancel()

            return result
        } catch {
            cancel()

            throw error
        }
    }
}

private extension CaptureAudioInputSession {
    func validateAudio() throws {
        guard audio.codec == .pcm else {
            throw CaptureError.audioCapture(
                "Live audio input currently supports PCM only."
            )
        }
    }

    func handle(
        _ buffer: CaptureAudioInputBuffer
    ) throws {
        let processed = try process(
            buffer
        )

        try handler(
            processed
        )
    }

    func process(
        _ buffer: CaptureAudioInputBuffer
    ) throws -> CaptureAudioInputBuffer {
        chainLock.lock()
        defer {
            chainLock.unlock()
        }

        return try chain.process(
            buffer
        )
    }

    func install(
        _ stream: CoreAudioInputStream,
        result: CaptureAudioInputStartResult
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
        self.startResult = result
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
            self.startResult = nil
        }
    }

    func takeStream() -> CoreAudioInputStream? {
        lock.lock()
        defer {
            lock.unlock()
        }

        let capturedStream = stream

        stream = nil
        startResult = nil

        return capturedStream
    }

    func currentStream() -> CoreAudioInputStream? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return stream
    }

    func currentResult() -> CaptureAudioInputStartResult? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return startResult
    }
}
