import Arguments

enum RecordCommand: ParsedArgumentCommand {
    typealias Options = RecordCommandOptions

    static let name = "record"

    static func run(
        _ options: RecordCommandOptions,
        invocation: ParsedInvocation
    ) async throws {
        try await RecordCommandRunner.run(
            options
        )
    }
}
