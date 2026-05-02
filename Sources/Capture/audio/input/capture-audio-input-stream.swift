import AudioToolbox
import Foundation

internal typealias CaptureAudioInputStartHandler = @Sendable (
    AudioStreamBasicDescription
) throws -> Void

internal typealias CaptureAudioInputBufferHandler = @Sendable (
    CaptureAudioInputBuffer
) throws -> Void

internal protocol CaptureAudioInputStream {
    func start() throws
    func stop() throws
    func firstSampleHostTimeSeconds() -> TimeInterval?
}
