import Foundation

public final class CaptureStopSignal: @unchecked Sendable {
    private let lock = NSLock()

    private var stopped = false
    private var continuations: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var cancelledWaits: Set<UUID> = []

    public init() {}

    public var isTriggered: Bool {
        isStopped()
    }

    public func stop() {
        let capturedContinuations = drainContinuations()

        for continuation in capturedContinuations {
            continuation.resume()
        }
    }

    public func wait() async {
        let id = UUID()

        await withTaskCancellationHandler {
            if isStopped() {
                return
            }

            await withCheckedContinuation { continuation in
                let shouldResume = addContinuation(
                    id: id,
                    continuation: continuation
                )

                if shouldResume {
                    continuation.resume()
                }
            }
        } onCancel: {
            if let continuation = self.cancelContinuation(
                id: id
            ) {
                continuation.resume()
            }
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
        id: UUID,
        continuation: CheckedContinuation<Void, Never>
    ) -> Bool {
        lock.lock()

        guard !stopped else {
            lock.unlock()
            return true
        }

        if cancelledWaits.remove(
            id
        ) != nil {
            lock.unlock()
            return true
        }

        continuations[id] = continuation

        lock.unlock()

        return false
    }

    func cancelContinuation(
        id: UUID
    ) -> CheckedContinuation<Void, Never>? {
        lock.lock()

        if stopped {
            lock.unlock()
            return nil
        }

        let continuation = continuations.removeValue(
            forKey: id
        )

        if continuation == nil {
            cancelledWaits.insert(
                id
            )
        }

        lock.unlock()

        return continuation
    }

    func drainContinuations() -> [CheckedContinuation<Void, Never>] {
        lock.lock()

        guard !stopped else {
            lock.unlock()
            return []
        }

        stopped = true

        let capturedContinuations = Array(
            continuations.values
        )

        continuations.removeAll()
        cancelledWaits.removeAll()

        lock.unlock()

        return capturedContinuations
    }
}
