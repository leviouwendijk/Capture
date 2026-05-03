import Foundation

public struct CaptureStartupRetryPolicy: Sendable, Codable, Hashable {
    public static let none = CaptureStartupRetryPolicy(
        attempts: 1,
        delaySeconds: 0
    )

    public static let cameraDefault = CaptureStartupRetryPolicy(
        attempts: 3,
        delaySeconds: 0.75
    )

    public let attempts: Int
    public let delaySeconds: TimeInterval

    public init(
        attempts: Int,
        delaySeconds: TimeInterval
    ) {
        self.attempts = max(
            1,
            attempts
        )
        self.delaySeconds = max(
            0,
            delaySeconds
        )
    }

    internal var delayNanoseconds: UInt64 {
        UInt64(
            delaySeconds * 1_000_000_000
        )
    }
}
