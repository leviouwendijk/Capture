import Foundation

internal final class CaptureReadinessSignal: @unchecked Sendable {
    internal enum State {
        case pending
        case ready
        case failed(any Error)
    }

    internal enum ContinuationAction {
        case wait
        case resumeReady
        case resumeFailure(any Error)
    }

    private let lock = NSLock()

    private var state: State = .pending
    private var continuations: [UUID: CheckedContinuation<Void, any Error>] = [:]
    private var cancelledWaits: Set<UUID> = []

    internal init() {}

    internal func ready() {
        complete(
            .ready
        )
    }

    internal func fail(
        _ error: any Error
    ) {
        complete(
            .failed(
                error
            )
        )
    }

    internal func wait() async throws {
        let id = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let action = addContinuation(
                    id: id,
                    continuation: continuation
                )

                switch action {
                case .wait:
                    return

                case .resumeReady:
                    continuation.resume()

                case .resumeFailure(let error):
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        } onCancel: {
            if let continuation = self.cancelContinuation(
                id: id
            ) {
                continuation.resume(
                    throwing: CancellationError()
                )
            }
        }
    }
}

private extension CaptureReadinessSignal {
    func complete(
        _ newState: State
    ) {
        lock.lock()

        guard case .pending = state else {
            lock.unlock()
            return
        }

        state = newState

        let capturedContinuations = Array(
            continuations.values
        )

        continuations.removeAll()
        cancelledWaits.removeAll()

        lock.unlock()

        for continuation in capturedContinuations {
            resume(
                continuation,
                state: newState
            )
        }
    }

    func addContinuation(
        id: UUID,
        continuation: CheckedContinuation<Void, any Error>
    ) -> ContinuationAction {
        lock.lock()
        defer {
            lock.unlock()
        }

        switch state {
        case .pending:
            if cancelledWaits.remove(
                id
            ) != nil {
                return .resumeFailure(
                    CancellationError()
                )
            }

            continuations[id] = continuation

            return .wait

        case .ready:
            return .resumeReady

        case .failed(let error):
            return .resumeFailure(
                error
            )
        }
    }

    func cancelContinuation(
        id: UUID
    ) -> CheckedContinuation<Void, any Error>? {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard case .pending = state else {
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

        return continuation
    }

    func resume(
        _ continuation: CheckedContinuation<Void, any Error>,
        state: State
    ) {
        switch state {
        case .pending:
            return

        case .ready:
            continuation.resume()

        case .failed(let error):
            continuation.resume(
                throwing: error
            )
        }
    }
}
