import Foundation

public struct CaptureAudioInputBuffer: Sendable {
    public let data: Data
    public let frameCount: Int
    public let packetCount: UInt32
    public let sampleRate: Int
    public let channelCount: Int
    public let hostTimeSeconds: TimeInterval?

    public init(
        data: Data,
        frameCount: Int,
        packetCount: UInt32,
        sampleRate: Int,
        channelCount: Int,
        hostTimeSeconds: TimeInterval?
    ) {
        self.data = data
        self.frameCount = frameCount
        self.packetCount = packetCount
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.hostTimeSeconds = hostTimeSeconds
    }

    public var isEmpty: Bool {
        data.isEmpty || frameCount <= 0
    }
}

public extension CaptureAudioInputBuffer {
    func withInt16Samples<Result>(
        _ body: (UnsafeBufferPointer<Int16>) throws -> Result
    ) rethrows -> Result {
        try data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(
                to: Int16.self
            )

            return try body(
                samples
            )
        }
    }

    func forEachMonoFloatSample(
        _ body: (Float) throws -> Void
    ) rethrows {
        guard channelCount > 0,
              frameCount > 0,
              !data.isEmpty else {
            return
        }

        try withInt16Samples { samples in
            let resolvedFrameCount = min(
                frameCount,
                samples.count / channelCount
            )

            guard resolvedFrameCount > 0 else {
                return
            }

            for frameIndex in 0..<resolvedFrameCount {
                var sum: Float = 0

                for channelIndex in 0..<channelCount {
                    let sampleIndex = frameIndex * channelCount + channelIndex

                    sum += Float(
                        samples[sampleIndex]
                    ) / 32768.0
                }

                try body(
                    sum / Float(
                        channelCount
                    )
                )
            }
        }
    }

    func appendMonoFloatSamples(
        to output: inout [Float]
    ) {
        forEachMonoFloatSample { sample in
            output.append(
                sample
            )
        }
    }

    func monoFloatSamples() -> [Float] {
        var output: [Float] = []

        output.reserveCapacity(
            max(
                0,
                frameCount
            )
        )

        appendMonoFloatSamples(
            to: &output
        )

        return output
    }
}
