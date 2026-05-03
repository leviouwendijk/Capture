import AudioToolbox
import Foundation

internal final class ChainAudioSink: CaptureAudioSink, @unchecked Sendable {
    private let downstream: any CaptureAudioSink
    private let lock = NSLock()

    private var chain: AudioChain

    internal init(
        downstream: any CaptureAudioSink,
        chain: AudioChain
    ) {
        self.downstream = downstream
        self.chain = chain
    }

    internal func start(
        format: AudioStreamBasicDescription
    ) throws {
        try downstream.start(
            format: format
        )
    }

    internal func append(
        _ buffer: CaptureAudioInputBuffer
    ) throws {
        let processed = try process(
            buffer
        )

        try downstream.append(
            processed
        )
    }

    internal func finish() throws {
        try downstream.finish()
    }

    internal func cancel() {
        downstream.cancel()
    }
}

private extension ChainAudioSink {
    func process(
        _ buffer: CaptureAudioInputBuffer
    ) throws -> CaptureAudioInputBuffer {
        lock.lock()
        defer {
            lock.unlock()
        }

        return try chain.process(
            buffer
        )
    }
}
