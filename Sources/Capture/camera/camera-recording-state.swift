import Foundation

internal final class CameraRecordingState: @unchecked Sendable {
    private let lock = NSLock()

    private var ready = false

    internal init() {}

    internal var isReady: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        return ready
    }

    internal func markReady() {
        lock.lock()
        ready = true
        lock.unlock()
    }
}
