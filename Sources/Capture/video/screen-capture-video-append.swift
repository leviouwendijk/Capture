internal enum ScreenCaptureVideoAppendResult: Sendable, Hashable {
    case appended
    case skipped(ScreenCaptureVideoAppendSkipReason)
}

internal enum ScreenCaptureVideoAppendSkipReason: String, Sendable, Codable, Hashable {
    case finished
    case failed
    case missingPixelBuffer
    case invalidPresentationTime
    case writerNotReady
    case appendFailed
}
