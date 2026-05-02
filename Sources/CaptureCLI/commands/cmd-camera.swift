import Arguments

enum CameraCommand: ParsedArgumentCommand {
    typealias Options = CameraCommandOptions

    static let name = "camera"

    static func run(
        _ options: CameraCommandOptions,
        invocation: ParsedInvocation
    ) async throws {
        try await CameraCommandRunner.run(
            options
        )
    }
}
