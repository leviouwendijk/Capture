import Foundation

public enum CaptureError: Error, Sendable, LocalizedError, Equatable {
    case invalidVideoSize(width: Int, height: Int)
    case invalidFrameRate(Int)
    case invalidSampleRate(Int)
    case invalidChannel(Int)
    case invalidDurationSeconds(Int)
    case unsupportedContainer(CaptureContainer)
    case missingOutput
    case noDevices(CaptureDevice.Kind)
    case invalidDisplayIndex(Int)
    case deviceNotFound(kind: CaptureDevice.Kind, value: String)
    case deviceDiscovery(String)
    case audioCapture(String)
    case videoCapture(String)
    case recordingNotImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .invalidVideoSize(let width, let height):
            return "Invalid video size: \(width)x\(height)."

        case .invalidFrameRate(let fps):
            return "Invalid frame rate: \(fps)."

        case .invalidSampleRate(let sampleRate):
            return "Invalid sample rate: \(sampleRate)."

        case .invalidChannel(let channel):
            return "Invalid audio channel: \(channel)."

        case .invalidDurationSeconds(let duration):
            return "Invalid duration: \(duration) seconds."

        case .unsupportedContainer(let container):
            return "Unsupported container: \(container.rawValue)."

        case .missingOutput:
            return "Missing output file."

        case .noDevices(let kind):
            return "No \(Self.description(for: kind)) devices were discovered."

        case .invalidDisplayIndex(let index):
            return "Invalid display index: \(index)."

        case .deviceNotFound(let kind, let value):
            return "Could not find \(Self.description(for: kind)) device: \(value)."

        case .deviceDiscovery(let message):
            return message

        case .audioCapture(let message):
            return message

        case .videoCapture(let message):
            return message

        case .recordingNotImplemented(let message):
            return message
        }
    }
}

private extension CaptureError {
    static func description(
        for kind: CaptureDevice.Kind
    ) -> String {
        switch kind {
        case .display:
            return "display"

        case .audio_input:
            return "audio input"
        }
    }
}
