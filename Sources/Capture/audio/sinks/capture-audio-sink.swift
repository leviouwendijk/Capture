import AudioToolbox
import Foundation

internal protocol CaptureAudioSink: AnyObject, Sendable {
    func start(
        format: AudioStreamBasicDescription
    ) throws

    func append(
        _ buffer: CaptureAudioInputBuffer
    ) throws

    func finish() throws

    func cancel()
}
