import Foundation

public struct CaptureFileOutput: Sendable, Codable, Hashable {
    public let url: URL

    public init(
        _ url: URL
    ) throws {
        guard !url.path.isEmpty else {
            throw CaptureError.missingOutput
        }

        self.url = url
    }
}
