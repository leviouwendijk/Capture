internal enum ScreenCaptureFrameSampleStatus: Sendable, Hashable {
    case complete
    case incomplete(rawValue: Int)
    case missing
}

