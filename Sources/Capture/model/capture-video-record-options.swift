// public struct CaptureVideoRecordOptions: Sendable, Codable, Hashable {
//     public static let standard = CaptureVideoRecordOptions(
//         uncheckedDuration: .standard
//     )

//     public let duration: CaptureRecordDuration

//     public init(
//         duration: CaptureRecordDuration = .standard
//     ) {
//         self.duration = duration
//     }

//     public init(
//         durationSeconds: Int = CaptureRecordDuration.standard.seconds
//     ) throws {
//         self.duration = try CaptureRecordDuration(
//             seconds: durationSeconds
//         )
//     }

//     private init(
//         uncheckedDuration duration: CaptureRecordDuration
//     ) {
//         self.duration = duration
//     }

//     public var durationSeconds: Int {
//         duration.seconds
//     }
// }
