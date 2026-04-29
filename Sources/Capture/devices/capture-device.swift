public struct CaptureDevice: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let kind: Kind
    public let detail: String?

    public enum Kind: String, Sendable, Codable, Hashable, CaseIterable {
        case display
        case audio_input
    }

    public init(
        id: String,
        name: String,
        kind: Kind,
        detail: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.detail = detail
    }

    public var label: String {
        guard let detail,
              !detail.isEmpty else {
            return "\(name)    id=\(id)"
        }

        return "\(name)    \(detail)    id=\(id)"
    }
}
