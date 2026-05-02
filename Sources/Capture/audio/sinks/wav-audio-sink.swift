import AudioToolbox
import Foundation

internal final class WAVAudioSink: CaptureAudioSink, @unchecked Sendable {
    private let output: URL
    private let lock = NSLock()

    private var audioFile: AudioFileID?
    private var packetIndex: Int64 = 0
    private var failure: Error?
    private var finished = false

    internal init(
        output: URL
    ) {
        self.output = output
    }

    internal func start(
        format: AudioStreamBasicDescription
    ) throws {
        try prepareOutputDirectory()

        lock.lock()
        defer {
            lock.unlock()
        }

        guard audioFile == nil else {
            throw CaptureError.audioCapture(
                "Audio output file is already open."
            )
        }

        var mutableFormat = format
        var createdFile: AudioFileID?

        try check(
            AudioFileCreateWithURL(
                output as CFURL,
                kAudioFileWAVEType,
                &mutableFormat,
                .eraseFile,
                &createdFile
            ),
            message: "Could not create audio output file."
        )

        guard let createdFile else {
            throw CaptureError.audioCapture(
                "Audio output file was not created."
            )
        }

        audioFile = createdFile
        packetIndex = 0
        failure = nil
        finished = false
    }

    internal func append(
        _ buffer: CaptureAudioInputBuffer
    ) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !finished else {
            return
        }

        if let failure {
            throw failure
        }

        guard let audioFile else {
            throw CaptureError.audioCapture(
                "Audio output file is not available."
            )
        }

        guard !buffer.data.isEmpty else {
            return
        }

        var packets = buffer.packetCount

        guard packets > 0 else {
            return
        }

        let status = buffer.data.withUnsafeBytes { bytes -> OSStatus in
            guard let baseAddress = bytes.baseAddress else {
                return -1
            }

            return AudioFileWritePackets(
                audioFile,
                false,
                UInt32(buffer.data.count),
                nil,
                packetIndex,
                &packets,
                baseAddress
            )
        }

        guard status == noErr else {
            let error = CaptureError.audioCapture(
                "Could not write audio packets. OSStatus=\(status)"
            )

            failure = error

            throw error
        }

        packetIndex += Int64(
            packets
        )
    }

    internal func finish() throws {
        lock.lock()

        let capturedFile = audioFile
        let capturedFailure = failure

        audioFile = nil
        finished = true

        lock.unlock()

        if let capturedFile {
            AudioFileClose(
                capturedFile
            )
        }

        if let capturedFailure {
            throw capturedFailure
        }
    }

    internal func cancel() {
        lock.lock()

        let capturedFile = audioFile

        audioFile = nil
        finished = true

        lock.unlock()

        if let capturedFile {
            AudioFileClose(
                capturedFile
            )
        }
    }
}

private extension WAVAudioSink {
    func prepareOutputDirectory() throws {
        let directory = output.deletingLastPathComponent()

        guard !directory.path.isEmpty else {
            return
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func check(
        _ status: OSStatus,
        message: String
    ) throws {
        guard status == noErr else {
            throw CaptureError.audioCapture(
                "\(message) OSStatus=\(status)"
            )
        }
    }
}
