import Foundation

public protocol AudioProcessor: Sendable {
    mutating func process(
        _ buffer: CaptureAudioInputBuffer
    ) throws -> CaptureAudioInputBuffer
}

public struct AudioChain: Sendable {
    private var processors: [any AudioProcessor]

    public init(
        processors: [any AudioProcessor] = []
    ) {
        self.processors = processors
    }

    public init(
        @AudioChainBuilder _ build: () -> [any AudioProcessor]
    ) {
        self.init(
            processors: build()
        )
    }

    public static var raw: AudioChain {
        AudioChain()
    }

    public var isEmpty: Bool {
        processors.isEmpty
    }

    public mutating func append(
        _ processor: any AudioProcessor
    ) {
        processors.append(
            processor
        )
    }

    public mutating func process(
        _ buffer: CaptureAudioInputBuffer
    ) throws -> CaptureAudioInputBuffer {
        var current = buffer

        for index in processors.indices {
            current = try processors[index].process(
                current
            )
        }

        return current
    }
}

@resultBuilder
public enum AudioChainBuilder {
    public static func buildExpression(
        _ processor: any AudioProcessor
    ) -> [any AudioProcessor] {
        [
            processor,
        ]
    }

    public static func buildExpression(
        _ processors: [any AudioProcessor]
    ) -> [any AudioProcessor] {
        processors
    }

    public static func buildBlock(
        _ parts: [any AudioProcessor]...
    ) -> [any AudioProcessor] {
        parts.flatMap {
            $0
        }
    }

    public static func buildOptional(
        _ processors: [any AudioProcessor]?
    ) -> [any AudioProcessor] {
        processors ?? []
    }

    public static func buildEither(
        first processors: [any AudioProcessor]
    ) -> [any AudioProcessor] {
        processors
    }

    public static func buildEither(
        second processors: [any AudioProcessor]
    ) -> [any AudioProcessor] {
        processors
    }

    public static func buildArray(
        _ processors: [[any AudioProcessor]]
    ) -> [any AudioProcessor] {
        processors.flatMap {
            $0
        }
    }
}
