public struct CaptureVideoRecordOptions: Sendable, Codable, Hashable {
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
}
