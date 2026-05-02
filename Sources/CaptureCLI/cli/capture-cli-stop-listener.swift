import Foundation
import Capture
import Darwin

internal final class CaptureCLIStopListener: @unchecked Sendable {
    private let stopSignal: CaptureStopSignal
    private let queue = DispatchQueue(
        label: "capture.cli.stop-listener"
    )

    private var interruptSource: DispatchSourceSignal?
    private var terminateSource: DispatchSourceSignal?
    private var inputTask: Task<Void, Never>?

    init(
        stopSignal: CaptureStopSignal
    ) {
        self.stopSignal = stopSignal
    }

    func start() {
        Darwin.signal(
            SIGINT,
            SIG_IGN
        )
        Darwin.signal(
            SIGTERM,
            SIG_IGN
        )

        let interruptSource = DispatchSource.makeSignalSource(
            signal: SIGINT,
            queue: queue
        )
        let terminateSource = DispatchSource.makeSignalSource(
            signal: SIGTERM,
            queue: queue
        )

        interruptSource.setEventHandler { [stopSignal] in
            stopSignal.stop()
        }
        terminateSource.setEventHandler { [stopSignal] in
            stopSignal.stop()
        }

        interruptSource.resume()
        terminateSource.resume()

        self.interruptSource = interruptSource
        self.terminateSource = terminateSource

        inputTask = Task.detached { [stopSignal] in
            while let line = readLine() {
                let value = line.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).lowercased()

                guard value == "q" else {
                    continue
                }

                stopSignal.stop()
                break
            }
        }
    }

    func stop() {
        interruptSource?.cancel()
        terminateSource?.cancel()
        inputTask?.cancel()

        Darwin.signal(
            SIGINT,
            SIG_DFL
        )
        Darwin.signal(
            SIGTERM,
            SIG_DFL
        )
    }
}
