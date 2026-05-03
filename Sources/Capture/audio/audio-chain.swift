import Foundation

public extension Audio {
    protocol Processor: Sendable {
        mutating func process(
            _ buffer: CaptureAudioInputBuffer
        ) throws -> CaptureAudioInputBuffer
    }

    struct Chain: Sendable {
        private var processors: [any Audio.Processor]

        public init(
            processors: [any Audio.Processor] = []
        ) {
            self.processors = processors
        }

        public init(
            @Audio.Builder _ build: () -> [any Audio.Processor]
        ) {
            self.init(
                processors: build()
            )
        }

        public static var raw: Audio.Chain {
            Audio.Chain()
        }

        public var isEmpty: Bool {
            processors.isEmpty
        }

        public mutating func append(
            _ processor: any Audio.Processor
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
    enum Builder {
        public static func buildExpression(
            _ processor: any Audio.Processor
        ) -> [any Audio.Processor] {
            [
                processor,
            ]
        }

        public static func buildExpression(
            _ processors: [any Audio.Processor]
        ) -> [any Audio.Processor] {
            processors
        }

        public static func buildBlock(
            _ parts: [any Audio.Processor]...
        ) -> [any Audio.Processor] {
            parts.flatMap {
                $0
            }
        }

        public static func buildOptional(
            _ processors: [any Audio.Processor]?
        ) -> [any Audio.Processor] {
            processors ?? []
        }

        public static func buildEither(
            first processors: [any Audio.Processor]
        ) -> [any Audio.Processor] {
            processors
        }

        public static func buildEither(
            second processors: [any Audio.Processor]
        ) -> [any Audio.Processor] {
            processors
        }

        public static func buildArray(
            _ processors: [[any Audio.Processor]]
        ) -> [any Audio.Processor] {
            processors.flatMap {
                $0
            }
        }
    }
}
