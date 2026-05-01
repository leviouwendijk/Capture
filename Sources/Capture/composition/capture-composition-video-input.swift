import Foundation

internal struct CaptureCompositionVideoInput: Sendable, Hashable {
    let source: CaptureCompositionSource
    let url: URL
    let startOffsetSeconds: TimeInterval

    init(
        source: CaptureCompositionSource,
        url: URL,
        startOffsetSeconds: TimeInterval
    ) {
        self.source = source
        self.url = url
        self.startOffsetSeconds = startOffsetSeconds
    }
}
