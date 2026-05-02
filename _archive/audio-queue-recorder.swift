// import Foundation

// // refactor to replace if possible (now that we have input -> sink) ?
// internal final class AudioQueueRecorder: @unchecked Sendable {
//     private let sink: WAVAudioSink
//     private let stream: CoreAudioInputStream

//     internal init(
//         device: CaptureDevice,
//         audio: CaptureAudioOptions,
//         output: URL
//     ) {
//         let sink = WAVAudioSink(
//             output: output
//         )

//         self.sink = sink
//         self.stream = CoreAudioInputStream(
//             device: device,
//             audio: audio,
//             startHandler: { format in
//                 try sink.start(
//                     format: format
//                 )
//             },
//             bufferHandler: { buffer in
//                 try sink.append(
//                     buffer
//                 )
//             }
//         )
//     }

//     internal func start() throws {
//         do {
//             try stream.start()
//         } catch {
//             sink.cancel()
//             throw error
//         }
//     }

//     internal func stop() throws {
//         var capturedError: Error?

//         do {
//             try stream.stop()
//         } catch {
//             capturedError = error
//         }

//         do {
//             try sink.finish()
//         } catch {
//             if capturedError == nil {
//                 capturedError = error
//             }
//         }

//         if let capturedError {
//             throw capturedError
//         }
//     }

//     internal func firstSampleHostTimeSeconds() -> TimeInterval? {
//         stream.firstSampleHostTimeSeconds()
//     }
// }

// // import AudioToolbox
// // import CoreAudio
// // import Foundation

// // internal final class AudioQueueRecorder: @unchecked Sendable {
// //     private let device: CaptureDevice
// //     private let audio: CaptureAudioOptions
// //     private let output: URL
// //     private let stateLock = NSLock()

// //     private var format: AudioStreamBasicDescription
// //     private var queue: AudioQueueRef?
// //     private var audioFile: AudioFileID?
// //     private var packetIndex: Int64 = 0
// //     private var isRunning = false
// //     private var callbackStatus: OSStatus = noErr
// //     private var firstInputHostTimeSeconds: TimeInterval?

// //     init(
// //         device: CaptureDevice,
// //         audio: CaptureAudioOptions,
// //         output: URL
// //     ) {
// //         self.device = device
// //         self.audio = audio
// //         self.output = output
// //         self.format = Self.makeFormat(
// //             audio: audio
// //         )
// //     }

// //     func start() throws {
// //         do {
// //             try prepareOutputDirectory()
// //             try createQueue()
// //             try setCurrentDevice()
// //             try createAudioFile()
// //             try enqueueBuffers()

// //             stateLock.lock()
// //             isRunning = true
// //             stateLock.unlock()

// //             try check(
// //                 AudioQueueStart(
// //                     requireQueue(),
// //                     nil
// //                 ),
// //                 message: "Could not start audio queue."
// //             )
// //         } catch {
// //             try? stop()
// //             throw error
// //         }
// //     }

// //     func stop() throws {
// //         stateLock.lock()
// //         let capturedQueue = queue
// //         let capturedFile = audioFile
// //         let capturedStatus = callbackStatus
// //         isRunning = false
// //         queue = nil
// //         audioFile = nil
// //         stateLock.unlock()

// //         if let capturedQueue {
// //             AudioQueueStop(
// //                 capturedQueue,
// //                 true
// //             )

// //             AudioQueueDispose(
// //                 capturedQueue,
// //                 true
// //             )
// //         }

// //         if let capturedFile {
// //             AudioFileClose(
// //                 capturedFile
// //             )
// //         }

// //         guard capturedStatus == noErr else {
// //             throw CaptureError.audioCapture(
// //                 "Could not write audio packets. OSStatus=\(capturedStatus)"
// //             )
// //         }
// //     }

// //     func firstSampleHostTimeSeconds() -> TimeInterval? {
// //         stateLock.lock()
// //         let value = firstInputHostTimeSeconds
// //         stateLock.unlock()

// //         return value
// //     }
// // }

// // private extension AudioQueueRecorder {
// //     static let inputCallback: AudioQueueInputCallback = {
// //         userData,
// //         queue,
// //         buffer,
// //         startTime,
// //         packetCount,
// //         packetDescriptions in

// //         guard let userData else {
// //             return
// //         }

// //         let recorder = Unmanaged<AudioQueueRecorder>
// //             .fromOpaque(
// //                 userData
// //             )
// //             .takeUnretainedValue()

// //         recorder.handleInput(
// //             queue: queue,
// //             buffer: buffer,
// //             inputHostTimeSeconds: AudioQueueRecorder.audioHostTimeSeconds(
// //                 from: startTime
// //             ),
// //             packetCount: packetCount,
// //             packetDescriptions: packetDescriptions
// //         )
// //     }

// //     static func makeFormat(
// //         audio: CaptureAudioOptions
// //     ) -> AudioStreamBasicDescription {
// //         let bytesPerSample = UInt32(2)
// //         let channels = UInt32(
// //             audio.channel
// //         )
// //         let bytesPerFrame = bytesPerSample * channels

// //         return AudioStreamBasicDescription(
// //             mSampleRate: Float64(
// //                 audio.sampleRate
// //             ),
// //             mFormatID: kAudioFormatLinearPCM,
// //             mFormatFlags: kLinearPCMFormatFlagIsSignedInteger
// //                 | kLinearPCMFormatFlagIsPacked,
// //             mBytesPerPacket: bytesPerFrame,
// //             mFramesPerPacket: 1,
// //             mBytesPerFrame: bytesPerFrame,
// //             mChannelsPerFrame: channels,
// //             mBitsPerChannel: 16,
// //             mReserved: 0
// //         )
// //     }

// //     static func audioHostTimeSeconds(
// //         from timestamp: UnsafePointer<AudioTimeStamp>
// //     ) -> TimeInterval? {
// //         let value = timestamp.pointee
// //         let flags = value.mFlags.rawValue
// //         let hostTimeValidFlag: UInt32 = 1 << 1

// //         guard (flags & hostTimeValidFlag) != 0,
// //               value.mHostTime > 0 else {
// //             return nil
// //         }

// //         let nanoseconds = AudioConvertHostTimeToNanos(
// //             value.mHostTime
// //         )

// //         return TimeInterval(
// //             nanoseconds
// //         ) / 1_000_000_000
// //     }

// //     func prepareOutputDirectory() throws {
// //         let directory = output.deletingLastPathComponent()

// //         guard !directory.path.isEmpty else {
// //             return
// //         }

// //         try FileManager.default.createDirectory(
// //             at: directory,
// //             withIntermediateDirectories: true
// //         )
// //     }

// //     func createQueue() throws {
// //         var queueFormat = format
// //         var createdQueue: AudioQueueRef?

// //         try check(
// //             AudioQueueNewInput(
// //                 &queueFormat,
// //                 Self.inputCallback,
// //                 Unmanaged.passUnretained(
// //                     self
// //                 ).toOpaque(),
// //                 nil,
// //                 nil,
// //                 0,
// //                 &createdQueue
// //             ),
// //             message: "Could not create audio input queue."
// //         )

// //         guard let createdQueue else {
// //             throw CaptureError.audioCapture(
// //                 "Audio input queue was not created."
// //             )
// //         }

// //         format = queueFormat
// //         queue = createdQueue
// //     }

// //     func setCurrentDevice() throws {
// //         let queue = try requireQueue()
// //         let uid = device.id as CFString
// //         var rawUID = Unmanaged.passUnretained(
// //             uid
// //         ).toOpaque()

// //         let status = withExtendedLifetime(
// //             uid
// //         ) {
// //             withUnsafeMutablePointer(
// //                 to: &rawUID
// //             ) {
// //                 AudioQueueSetProperty(
// //                     queue,
// //                     kAudioQueueProperty_CurrentDevice,
// //                     $0,
// //                     UInt32(
// //                         MemoryLayout<UnsafeMutableRawPointer>.size
// //                     )
// //                 )
// //             }
// //         }

// //         try check(
// //             status,
// //             message: "Could not select audio input device \(device.name)."
// //         )
// //     }

// //     func createAudioFile() throws {
// //         var createdFile: AudioFileID?

// //         try check(
// //             AudioFileCreateWithURL(
// //                 output as CFURL,
// //                 kAudioFileWAVEType,
// //                 &format,
// //                 .eraseFile,
// //                 &createdFile
// //             ),
// //             message: "Could not create audio output file."
// //         )

// //         guard let createdFile else {
// //             throw CaptureError.audioCapture(
// //                 "Audio output file was not created."
// //             )
// //         }

// //         audioFile = createdFile
// //     }

// //     func enqueueBuffers() throws {
// //         let queue = try requireQueue()
// //         let framesPerBuffer = UInt32(
// //             max(
// //                 1024,
// //                 audio.sampleRate / 10
// //             )
// //         )
// //         let bufferByteSize = max(
// //             format.mBytesPerFrame * framesPerBuffer,
// //             format.mBytesPerFrame
// //         )

// //         for _ in 0..<3 {
// //             var buffer: AudioQueueBufferRef?

// //             try check(
// //                 AudioQueueAllocateBuffer(
// //                     queue,
// //                     bufferByteSize,
// //                     &buffer
// //                 ),
// //                 message: "Could not allocate audio input buffer."
// //             )

// //             guard let buffer else {
// //                 throw CaptureError.audioCapture(
// //                     "Audio input buffer was not allocated."
// //                 )
// //             }

// //             try check(
// //                 AudioQueueEnqueueBuffer(
// //                     queue,
// //                     buffer,
// //                     0,
// //                     nil
// //                 ),
// //                 message: "Could not enqueue audio input buffer."
// //             )
// //         }
// //     }

// //     func handleInput(
// //         queue: AudioQueueRef,
// //         buffer: AudioQueueBufferRef,
// //         inputHostTimeSeconds: TimeInterval?,
// //         packetCount: UInt32,
// //         packetDescriptions: UnsafePointer<AudioStreamPacketDescription>?
// //     ) {
// //         stateLock.lock()

// //         guard isRunning,
// //               let audioFile,
// //               callbackStatus == noErr else {
// //             stateLock.unlock()
// //             return
// //         }

// //         var packets = packetCount

// //         if packets == 0,
// //            format.mBytesPerPacket > 0 {
// //             packets = buffer.pointee.mAudioDataByteSize / format.mBytesPerPacket
// //         }

// //         if firstInputHostTimeSeconds == nil,
// //            packets > 0,
// //            let inputHostTimeSeconds {
// //             firstInputHostTimeSeconds = inputHostTimeSeconds
// //         }

// //         let status = AudioFileWritePackets(
// //             audioFile,
// //             false,
// //             buffer.pointee.mAudioDataByteSize,
// //             packetDescriptions,
// //             packetIndex,
// //             &packets,
// //             buffer.pointee.mAudioData
// //         )

// //         if status == noErr {
// //             packetIndex += Int64(
// //                 packets
// //             )
// //         } else {
// //             callbackStatus = status
// //         }

// //         let shouldContinue = isRunning
// //             && callbackStatus == noErr

// //         stateLock.unlock()

// //         guard shouldContinue else {
// //             return
// //         }

// //         AudioQueueEnqueueBuffer(
// //             queue,
// //             buffer,
// //             0,
// //             nil
// //         )
// //     }

// //     func requireQueue() throws -> AudioQueueRef {
// //         guard let queue else {
// //             throw CaptureError.audioCapture(
// //                 "Audio queue is not available."
// //             )
// //         }

// //         return queue
// //     }

// //     func check(
// //         _ status: OSStatus,
// //         message: String
// //     ) throws {
// //         guard status == noErr else {
// //             throw CaptureError.audioCapture(
// //                 "\(message) OSStatus=\(status)"
// //             )
// //         }
// //     }
// // }
