public struct CaptureRecordOptions: Sendable, Codable, Hashable {
    public static let standard = CaptureRecordOptions(
        uncheckedDurationSeconds: 5
    )

    public let durationSeconds: Int

    public init(
        durationSeconds: Int = 5
    ) throws {
        guard durationSeconds > 0 else {
            throw CaptureError.invalidDurationSeconds(
                durationSeconds
            )
        }

        self.durationSeconds = durationSeconds
    }

    private init(
        uncheckedDurationSeconds: Int
    ) {
        self.durationSeconds = uncheckedDurationSeconds
    }
}
