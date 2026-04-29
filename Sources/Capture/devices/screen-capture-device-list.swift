import CoreGraphics
import ScreenCaptureKit

struct ScreenCaptureDeviceList: Sendable {
    func devices() async throws -> [CaptureDevice] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        let mainDisplayID = CGMainDisplayID()

        return content.displays
            .enumerated()
            .map { index, display in
                let id = String(
                    display.displayID
                )
                let name: String

                if display.displayID == mainDisplayID {
                    name = "Main Display"
                } else {
                    name = "Display \(index)"
                }

                return CaptureDevice(
                    id: id,
                    name: name,
                    kind: .display,
                    detail: "\(display.width)x\(display.height)"
                )
            }
    }
}
