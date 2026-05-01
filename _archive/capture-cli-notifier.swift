// ATTEMPTED NATIVE NOTIFS
// FAILURE BECAUSE OF AUTH SIGNING

import Capture
import Foundation
import UserNotifications

internal struct CaptureCLINotifier: Sendable {
    internal static let standard = CaptureCLINotifier()

    internal func partialRecordingRetained(
        _ error: CapturePartialRecordingError
    ) async {
        await notify(
            .partialRecordingRetained(
                error
            )
        )
    }

    internal func recordingFailed(
        _ error: Error
    ) async {
        await notify(
            .recordingFailed(
                error
            )
        )
    }

    internal func testNotification() async throws {
        try await CaptureCLIUserNotificationCenter.shared.send(
            CaptureUserNotification(
                title: "Capture notification test",
                message: "Direct UserNotifications delivery is working."
            )
        )
    }

    internal func printNotificationStatus() async {
        let status = await CaptureCLIUserNotificationCenter.shared.status()

        fputs(
            """
            notification:
              bundle id: \(Bundle.main.bundleIdentifier ?? "<none>")
              bundle path: \(Bundle.main.bundlePath)
              authorization: \(status)

            """,
            stderr
        )
    }
}

private extension CaptureCLINotifier {
    static let delegate = CaptureCLIUserNotificationDelegate()

    func notify(
        _ notification: CaptureUserNotification
    ) async {
        do {
            try await CaptureCLIUserNotificationCenter.shared.send(
                notification
            )
        } catch {
            fputs(
                "capture notification: \(error.localizedDescription)\n",
                stderr
            )
        }
    }
}

private enum CaptureCLIUserNotificationError: Error, LocalizedError {
    case notAuthorized(UNAuthorizationStatus)
    case authorizationDenied
    case missingBundleIdentifier

    var errorDescription: String? {
        switch self {
        case .notAuthorized(let status):
            return "Notifications are not authorized for Capture. Current status: \(status.captureDescription)."

        case .authorizationDenied:
            return "Notification permission was denied for Capture."

        case .missingBundleIdentifier:
            return "Capture has no bundle identifier at runtime, so macOS may refuse direct notifications."
        }
    }
}

private final class CaptureCLIUserNotificationCenter: Sendable {
    static let shared = CaptureCLIUserNotificationCenter()

    private init() {}

    func status() async -> String {
        let center = UNUserNotificationCenter.current()
        let status = await authorizationStatus(
            center: center
        )

        return status.captureDescription
    }

    func send(
        _ notification: CaptureUserNotification
    ) async throws {
        guard Bundle.main.bundleIdentifier != nil else {
            throw CaptureCLIUserNotificationError.missingBundleIdentifier
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = CaptureCLINotifier.delegate

        try await ensureAuthorization(
            center: center
        )

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = .default
        content.threadIdentifier = "capture"

        let request = UNNotificationRequest(
            identifier: "capture-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: 0.1,
                repeats: false
            )
        )

        try await add(
            request,
            to: center
        )

        try await Task.sleep(
            nanoseconds: 2_000_000_000
        )
    }

    func ensureAuthorization(
        center: UNUserNotificationCenter
    ) async throws {
        let status = await authorizationStatus(
            center: center
        )

        switch status {
        case .authorized,
             .provisional,
             .ephemeral:
            return

        case .notDetermined:
            let granted = try await requestAuthorization(
                center: center
            )

            guard granted else {
                throw CaptureCLIUserNotificationError.authorizationDenied
            }

        case .denied:
            throw CaptureCLIUserNotificationError.notAuthorized(
                status
            )

        @unknown default:
            throw CaptureCLIUserNotificationError.notAuthorized(
                status
            )
        }
    }

    func authorizationStatus(
        center: UNUserNotificationCenter
    ) async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(
                    returning: settings.authorizationStatus
                )
            }
        }
    }

    func requestAuthorization(
        center: UNUserNotificationCenter
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Bool, Error>
        ) in
            center.requestAuthorization(
                options: [
                    .alert,
                    .sound,
                ]
            ) { granted, error in
                if let error {
                    continuation.resume(
                        throwing: error
                    )
                } else {
                    continuation.resume(
                        returning: granted
                    )
                }
            }
        }
    }

    func add(
        _ request: UNNotificationRequest,
        to center: UNUserNotificationCenter
    ) async throws {
        try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Void, Error>
        ) in
            center.add(
                request
            ) { error in
                if let error {
                    continuation.resume(
                        throwing: error
                    )
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

private final class CaptureCLIUserNotificationDelegate:
    NSObject,
    UNUserNotificationCenterDelegate,
    @unchecked Sendable
{
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [
            .banner,
            .list,
            .sound,
        ]
    }
}

private extension UNAuthorizationStatus {
    var captureDescription: String {
        switch self {
        case .notDetermined:
            return "notDetermined"

        case .denied:
            return "denied"

        case .authorized:
            return "authorized"

        case .provisional:
            return "provisional"

        case .ephemeral:
            return "ephemeral"

        @unknown default:
            return "unknown"
        }
    }
}
