import Arguments

enum TestCommand: ArgumentCommand {
    static let name = "test"

    static let children: [ArgumentCommandType] = [
        Fail.self,
    ]

    enum Fail: RunnableArgumentCommand {
        static let name = "fail"

        static func run(
            _ invocation: ParsedInvocation
        ) async throws {
            try CaptureCLI.simulatePartialRecordingFailure()
        }
    }
}
