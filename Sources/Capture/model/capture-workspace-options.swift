import Foundation

public struct CaptureWorkspaceOptions: Sendable, Codable, Hashable {
    public static let standard = CaptureWorkspaceOptions()

    public let root: URL?

    public init(
        root: URL? = nil
    ) {
        self.root = root
    }

    public var resolvedRoot: URL {
        root ?? FileManager.default.temporaryDirectory
    }
}
