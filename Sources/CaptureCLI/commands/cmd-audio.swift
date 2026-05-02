import Arguments

enum AudioCommand: ParsedArgumentCommand {
    typealias Options = AudioCommandOptions

    static let name = "audio"

    static func run(
        _ options: AudioCommandOptions,
        invocation: ParsedInvocation
    ) async throws {
        try await AudioCommandRunner.run(
            options
        )
    }
}
