import AVFoundation
import Foundation

internal final class CameraCaptureRuntimeObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []

    internal init(
        session: AVCaptureSession,
        deviceName: String,
        onFailure: @escaping @Sendable (Error) -> Void
    ) {
        let runtimeToken = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: session,
            queue: nil
        ) { notification in
            let error = Self.runtimeError(
                notification: notification,
                deviceName: deviceName
            )

            onFailure(
                error
            )
        }

        let interruptedToken = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: session,
            queue: nil
        ) { notification in
            let error = Self.interruptionError(
                notification: notification,
                deviceName: deviceName
            )

            onFailure(
                error
            )
        }

        tokens = [
            runtimeToken,
            interruptedToken,
        ]
    }

    deinit {
        invalidate()
    }

    internal func invalidate() {
        lock.lock()

        let capturedTokens = tokens
        tokens.removeAll()

        lock.unlock()

        for token in capturedTokens {
            NotificationCenter.default.removeObserver(
                token
            )
        }
    }
}

private extension CameraCaptureRuntimeObserver {
    static func runtimeError(
        notification: Notification,
        deviceName: String
    ) -> Error {
        let nsError = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError

        if let nsError {
            return CaptureError.videoCapture(
                "Camera \(deviceName) capture session failed at runtime. \(describe(nsError))"
            )
        }

        return CaptureError.videoCapture(
            "Camera \(deviceName) capture session failed at runtime. userInfo=\(String(describing: notification.userInfo))"
        )
    }

    static func interruptionError(
        notification: Notification,
        deviceName: String
    ) -> Error {
        CaptureError.videoCapture(
            "Camera \(deviceName) capture session was interrupted. userInfo=\(String(describing: notification.userInfo))"
        )
    }

    static func describe(
        _ error: NSError
    ) -> String {
        "domain=\(error.domain) code=\(error.code) description=\(error.localizedDescription) userInfo=\(error.userInfo)"
    }
}
