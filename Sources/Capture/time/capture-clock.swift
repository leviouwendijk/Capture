import CoreMedia
import Foundation

internal enum CaptureClock {
    static func hostTimeSeconds() -> TimeInterval {
        let time = CMClockGetTime(
            CMClockGetHostTimeClock()
        )
        let seconds = CMTimeGetSeconds(
            time
        )

        guard seconds.isFinite else {
            return ProcessInfo.processInfo.systemUptime
        }

        return seconds
    }
}
