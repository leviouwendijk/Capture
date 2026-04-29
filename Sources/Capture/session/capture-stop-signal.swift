import Foundation

public final class CaptureStopSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func stop() {
        let capturedContinuations = drainContinuations()

        for continuation in capturedContinuations {
            continuation.resume()
        }
    }

    public func wait() async {
        await withTaskCancellationHandler {
            if isStopped() {
                return
            }

            await withCheckedContinuation { continuation in
                let shouldResume = addContinuation(
                    continuation
                )

                if shouldResume {
                    continuation.resume()
                }
            }
        } onCancel: {
            self.stop()
        }
    }
}

private extension CaptureStopSignal {
    func isStopped() -> Bool {
        lock.lock()
        let value = stopped
        lock.unlock()

        return value
    }

    func addContinuation(
        _ continuation: CheckedContinuation<Void, Never>
    ) -> Bool {
        lock.lock()

        guard !stopped else {
            lock.unlock()
            return true
        }

        continuations.append(
            continuation
        )

        lock.unlock()

        return false
    }

    func drainContinuations() -> [CheckedContinuation<Void, Never>] {
        lock.lock()

        guard !stopped else {
            lock.unlock()
            return []
        }

        stopped = true
        let capturedContinuations = continuations
        continuations.removeAll()

        lock.unlock()

        return capturedContinuations
    }
}
