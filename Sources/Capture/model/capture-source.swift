public enum CaptureDisplay: Sendable, Codable, Hashable {
    case main
    case index(Int)
    case displayIdentifier(UInt32)
}

public enum CaptureVideoInput: Sendable, Codable, Hashable {
    case systemDefault
    case name(String)
    case identifier(String)
}

public enum CaptureAudioDevice: Sendable, Codable, Hashable {
    case systemDefault
    case name(String)
    case identifier(String)
}
