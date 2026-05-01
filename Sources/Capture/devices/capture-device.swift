public struct CaptureVideoSize: Sendable, Codable, Hashable {
    public let width: Int
    public let height: Int

    public init(
        width: Int,
        height: Int
    ) {
        self.width = width
        self.height = height
    }

    public var label: String {
        "\(width)x\(height)"
    }
}

public struct CaptureDevice: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let kind: Kind
    public let detail: String?
    public let size: CaptureVideoSize?

    public enum Kind: String, Sendable, Codable, Hashable, CaseIterable {
        case display
        case video_input
        case audio_input
    }

    public init(
        id: String,
        name: String,
        kind: Kind,
        detail: String? = nil,
        size: CaptureVideoSize? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.detail = detail
        self.size = size
    }

    public var label: String {
        let resolvedDetail = detail ?? size?.label

        guard let resolvedDetail,
              !resolvedDetail.isEmpty else {
            return "\(name)    id=\(id)"
        }

        return "\(name)    \(resolvedDetail)    id=\(id)"
    }
}
