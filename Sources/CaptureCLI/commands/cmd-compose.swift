import Arguments

enum ComposeCommand: ParsedArgumentCommand {
    typealias Options = ComposeCommandOptions

    static let name = "compose"

    static func run(
        _ options: ComposeCommandOptions,
        invocation: ParsedInvocation
    ) async throws {
        try await ComposeCommandRunner.run(
            options
        )
    }
}
