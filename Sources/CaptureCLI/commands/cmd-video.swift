import Arguments

enum VideoCommand: ParsedArgumentCommand {
    typealias Options = VideoCommandOptions

    static let name = "video"

    static func run(
        _ options: VideoCommandOptions,
        invocation: ParsedInvocation
    ) async throws {
        try await VideoCommandRunner.run(
            options
        )
    }
}
