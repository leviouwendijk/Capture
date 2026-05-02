import Foundation

public struct CaptureRecordDuration: Sendable, Codable, Hashable {
    public static let standard = CaptureRecordDuration(
        uncheckedSeconds: 5
    )

    public let seconds: Int

    public init(
        seconds: Int
    ) throws {
        guard seconds > 0 else {
            throw CaptureError.invalidDurationSeconds(
                seconds
            )
        }

        self.seconds = seconds
    }

    public init(
        _ seconds: Int
    ) throws {
        try self.init(
            seconds: seconds
        )
    }

    internal init(
        uncheckedSeconds seconds: Int
    ) {
        self.seconds = seconds
    }

    public var interval: TimeInterval {
        TimeInterval(
            seconds
        )
    }
}

public enum CaptureRecordMode: Sendable, Codable, Hashable {
    case live
    case duration(CaptureRecordDuration)

    public init(
        durationSeconds: Int?
    ) throws {
        if let durationSeconds {
            self = try .duration(
                CaptureRecordDuration(
                    seconds: durationSeconds
                )
            )
        } else {
            self = .live
        }
    }

    public var duration: CaptureRecordDuration? {
        switch self {
        case .live:
            return nil

        case .duration(let duration):
            return duration
        }
    }

    public var durationSeconds: Int? {
        duration?.seconds
    }
}
