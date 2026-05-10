import Foundation
import IOKit.pwr_mgt

final class CapturePowerAssertion {
    private var assertionID: IOPMAssertionID = 0
    private var isActive = false

    init(
        reason: String
    ) throws {
        var id = IOPMAssertionID(0)

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )

        guard result == kIOReturnSuccess else {
            throw CaptureError.powerAssertion(
                "Unable to prevent display sleep. IOKit returned \(result)."
            )
        }

        assertionID = id
        isActive = true
    }

    func release() {
        guard isActive else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }

    deinit {
        release()
    }
}
