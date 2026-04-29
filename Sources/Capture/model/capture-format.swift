public enum CaptureContainer: String, Sendable, Codable, Hashable, CaseIterable {
    case mov
    case mp4
}

public enum CaptureVideoCodec: String, Sendable, Codable, Hashable, CaseIterable {
    case h264
}

public enum CaptureAudioCodec: String, Sendable, Codable, Hashable, CaseIterable {
    case pcm
    case aac
}
