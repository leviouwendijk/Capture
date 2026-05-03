import Foundation

internal struct CaptureTimedStopSignal: Sendable {
    internal let stopSignal: CaptureStopSignal

    private let task: Task<Void, Never>

    internal init(
        duration: CaptureRecordDuration
    ) {
        let stopSignal = CaptureStopSignal()

        self.stopSignal = stopSignal
        self.task = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(duration.seconds) * 1_000_000_000
            )

            guard !Task.isCancelled else {
                return
            }

            stopSignal.stop()
        }
    }

    internal func cancel() {
        task.cancel()
    }
}
