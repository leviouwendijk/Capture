import AudioToolbox
import CoreAudio
import Foundation

internal final class CoreAudioInputStream: CaptureAudioInputStream, @unchecked Sendable {
    private let device: CaptureDevice
    private let audio: CaptureAudioOptions
    private let startHandler: CaptureAudioInputStartHandler
    private let bufferHandler: CaptureAudioInputBufferHandler
    private let stateLock = NSLock()

    private var format: AudioStreamBasicDescription
    private var queue: AudioQueueRef?
    private var isRunning = false
    private var callbackStatus: OSStatus = noErr
    private var callbackError: Error?
    private var firstInputHostTimeSeconds: TimeInterval?

    internal init(
        device: CaptureDevice,
        audio: CaptureAudioOptions,
        startHandler: @escaping CaptureAudioInputStartHandler = { _ in },
        bufferHandler: @escaping CaptureAudioInputBufferHandler
    ) {
        self.device = device
        self.audio = audio
        self.startHandler = startHandler
        self.bufferHandler = bufferHandler
        self.format = Self.makeFormat(
            audio: audio
        )
    }

    internal func start() throws {
        do {
            try validateAudio()
            try createQueue()
            try setCurrentDevice()

            try startHandler(
                format
            )

            try enqueueBuffers()

            stateLock.lock()
            isRunning = true
            callbackStatus = noErr
            callbackError = nil
            stateLock.unlock()

            try check(
                AudioQueueStart(
                    requireQueue(),
                    nil
                ),
                message: "Could not start audio queue."
            )
        } catch {
            try? stop()
            throw error
        }
    }

    internal func stop() throws {
        stateLock.lock()

        let capturedQueue = queue
        let capturedStatus = callbackStatus
        let capturedError = callbackError

        isRunning = false
        queue = nil

        stateLock.unlock()

        if let capturedQueue {
            AudioQueueStop(
                capturedQueue,
                true
            )

            AudioQueueDispose(
                capturedQueue,
                true
            )
        }

        if let capturedError {
            throw capturedError
        }

        guard capturedStatus == noErr else {
            throw CaptureError.audioCapture(
                "Could not capture audio packets. OSStatus=\(capturedStatus)"
            )
        }
    }

    internal func firstSampleHostTimeSeconds() -> TimeInterval? {
        stateLock.lock()
        let value = firstInputHostTimeSeconds
        stateLock.unlock()

        return value
    }
}

private extension CoreAudioInputStream {
    static let inputCallback: AudioQueueInputCallback = {
        userData,
        queue,
        buffer,
        startTime,
        packetCount,
        packetDescriptions in

        guard let userData else {
            return
        }

        let stream = Unmanaged<CoreAudioInputStream>
            .fromOpaque(
                userData
            )
            .takeUnretainedValue()

        stream.handleInput(
            queue: queue,
            buffer: buffer,
            inputHostTimeSeconds: CoreAudioInputStream.audioHostTimeSeconds(
                from: startTime
            ),
            packetCount: packetCount,
            packetDescriptions: packetDescriptions
        )
    }

    static func makeFormat(
        audio: CaptureAudioOptions
    ) -> AudioStreamBasicDescription {
        let bytesPerSample = UInt32(2)
        let channels = UInt32(
            audio.channel
        )
        let bytesPerFrame = bytesPerSample * channels

        return AudioStreamBasicDescription(
            mSampleRate: Float64(
                audio.sampleRate
            ),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger
                | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 16,
            mReserved: 0
        )
    }

    static func audioHostTimeSeconds(
        from timestamp: UnsafePointer<AudioTimeStamp>
    ) -> TimeInterval? {
        let value = timestamp.pointee
        let flags = value.mFlags.rawValue
        let hostTimeValidFlag: UInt32 = 1 << 1

        guard (flags & hostTimeValidFlag) != 0,
              value.mHostTime > 0 else {
            return nil
        }

        let nanoseconds = AudioConvertHostTimeToNanos(
            value.mHostTime
        )

        return TimeInterval(
            nanoseconds
        ) / 1_000_000_000
    }

    func validateAudio() throws {
        guard audio.codec == .pcm else {
            throw CaptureError.audioCapture(
                "CoreAudio input stream currently supports PCM only."
            )
        }
    }

    func createQueue() throws {
        var queueFormat = format
        var createdQueue: AudioQueueRef?

        try check(
            AudioQueueNewInput(
                &queueFormat,
                Self.inputCallback,
                Unmanaged.passUnretained(
                    self
                ).toOpaque(),
                nil,
                nil,
                0,
                &createdQueue
            ),
            message: "Could not create audio input queue."
        )

        guard let createdQueue else {
            throw CaptureError.audioCapture(
                "Audio input queue was not created."
            )
        }

        format = queueFormat
        queue = createdQueue
    }

    func setCurrentDevice() throws {
        let queue = try requireQueue()
        let uid = device.id as CFString
        var rawUID = Unmanaged.passUnretained(
            uid
        ).toOpaque()

        let status = withExtendedLifetime(
            uid
        ) {
            withUnsafeMutablePointer(
                to: &rawUID
            ) {
                AudioQueueSetProperty(
                    queue,
                    kAudioQueueProperty_CurrentDevice,
                    $0,
                    UInt32(
                        MemoryLayout<UnsafeMutableRawPointer>.size
                    )
                )
            }
        }

        try check(
            status,
            message: "Could not select audio input device \(device.name)."
        )
    }

    func enqueueBuffers() throws {
        let queue = try requireQueue()
        let framesPerBuffer = UInt32(
            max(
                1024,
                audio.sampleRate / 10
            )
        )
        let bufferByteSize = max(
            format.mBytesPerFrame * framesPerBuffer,
            format.mBytesPerFrame
        )

        for _ in 0..<3 {
            var buffer: AudioQueueBufferRef?

            try check(
                AudioQueueAllocateBuffer(
                    queue,
                    bufferByteSize,
                    &buffer
                ),
                message: "Could not allocate audio input buffer."
            )

            guard let buffer else {
                throw CaptureError.audioCapture(
                    "Audio input buffer was not allocated."
                )
            }

            try check(
                AudioQueueEnqueueBuffer(
                    queue,
                    buffer,
                    0,
                    nil
                ),
                message: "Could not enqueue audio input buffer."
            )
        }
    }

    func handleInput(
        queue: AudioQueueRef,
        buffer: AudioQueueBufferRef,
        inputHostTimeSeconds: TimeInterval?,
        packetCount: UInt32,
        packetDescriptions: UnsafePointer<AudioStreamPacketDescription>?
    ) {
        let inputBuffer: CaptureAudioInputBuffer

        stateLock.lock()

        guard isRunning,
              callbackStatus == noErr,
              callbackError == nil else {
            stateLock.unlock()
            return
        }

        var packets = packetCount

        if packets == 0,
           format.mBytesPerPacket > 0 {
            packets = buffer.pointee.mAudioDataByteSize / format.mBytesPerPacket
        }

        if firstInputHostTimeSeconds == nil,
           packets > 0,
           let inputHostTimeSeconds {
            firstInputHostTimeSeconds = inputHostTimeSeconds
        }

        let byteCount = Int(
            buffer.pointee.mAudioDataByteSize
        )
        let bytesPerFrame = Int(
            format.mBytesPerFrame
        )
        let frameCount: Int

        if bytesPerFrame > 0 {
            frameCount = byteCount / bytesPerFrame
        } else {
            frameCount = Int(
                packets
            )
        }

        let data: Data

        if byteCount > 0 {
            data = Data(
                bytes: buffer.pointee.mAudioData,
                count: byteCount
            )
        } else {
            data = Data()
        }

        inputBuffer = CaptureAudioInputBuffer(
            data: data,
            frameCount: frameCount,
            packetCount: packets,
            sampleRate: Int(
                format.mSampleRate.rounded()
            ),
            channelCount: Int(
                format.mChannelsPerFrame
            ),
            hostTimeSeconds: inputHostTimeSeconds
        )

        stateLock.unlock()

        do {
            try bufferHandler(
                inputBuffer
            )
        } catch {
            recordCallbackError(
                error
            )
        }

        stateLock.lock()

        let shouldContinue = isRunning
            && callbackStatus == noErr
            && callbackError == nil

        stateLock.unlock()

        guard shouldContinue else {
            return
        }

        let enqueueStatus = AudioQueueEnqueueBuffer(
            queue,
            buffer,
            0,
            nil
        )

        guard enqueueStatus != noErr else {
            return
        }

        recordCallbackStatus(
            enqueueStatus
        )
    }

    func recordCallbackStatus(
        _ status: OSStatus
    ) {
        stateLock.lock()

        if callbackStatus == noErr {
            callbackStatus = status
        }

        stateLock.unlock()
    }

    func recordCallbackError(
        _ error: Error
    ) {
        stateLock.lock()

        if callbackError == nil {
            callbackError = error
        }

        stateLock.unlock()
    }

    func requireQueue() throws -> AudioQueueRef {
        guard let queue else {
            throw CaptureError.audioCapture(
                "Audio queue is not available."
            )
        }

        return queue
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
