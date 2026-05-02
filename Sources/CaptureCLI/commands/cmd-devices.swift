import Arguments
import Capture

enum DevicesCommand: RunnableArgumentCommand {
    static let name = "devices"

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        try await CaptureCLI.printDevices(
            provider: MacCaptureDeviceProvider()
        )
    }
}
