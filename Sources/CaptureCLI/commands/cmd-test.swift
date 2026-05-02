import Arguments

enum TestCommand: ArgumentCommand {
    static let name = "test"

    static let children: [ArgumentCommandType] = [
        Fail.self,
        LiveAudio.self,
    ]

    enum Fail: RunnableArgumentCommand {
        static let name = "fail"

        static func run(
            _ invocation: ParsedInvocation
        ) async throws {
            try CaptureCLI.simulatePartialRecordingFailure()
        }
    }

    enum LiveAudio: ParsedArgumentCommand {
        typealias Options = LiveAudioSmokeCommandOptions

        static let name = "live-audio"

        static func run(
            _ options: LiveAudioSmokeCommandOptions,
            invocation: ParsedInvocation
        ) async throws {
            try await CaptureCLI.runLiveAudioSmoke(
                options: options.smoke
            )
        }
    }
}
