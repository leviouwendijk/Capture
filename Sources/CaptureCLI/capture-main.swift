import Arguments
import Capture
import Foundation

@main
enum CaptureCLICommand: ArgumentCommand {
    static let name = "capturer"
    static let defaultChild = HelpCommand.self

    static let children: [ArgumentCommandType] = [
        HelpCommand.self,
        DevicesCommand.self,
        TestCommand.self,
        AudioCommand.self,
        VideoCommand.self,
        CameraCommand.self,
        ComposeCommand.self,
        RecordCommand.self,
    ]

    static func main() async {
        await ArgumentProgram.main(
            command: Self.self,
            errorHandler: { error in
                CaptureCLI.writeError(
                    error
                )

                return 1
            }
        )
    }
}

enum HelpCommand: RunnableArgumentCommand {
    static let name = "help"

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        print(
            ArgumentHelpRenderer().render(
                command: try CaptureCLICommand.spec()
            )
        )
    }
}
