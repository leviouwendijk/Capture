import Foundation

internal enum CaptureErrorDescription {
    internal static func technical(
        _ error: Error
    ) -> String {
        technical(
            error as NSError
        )
    }

    internal static func technical(
        _ error: NSError
    ) -> String {
        "\(error.localizedDescription) domain=\(error.domain) code=\(error.code) userInfo=\(error.userInfo)"
    }

    internal static func prefixed(
        _ prefix: String,
        error: Error
    ) -> String {
        "\(prefix) \(technical(error))"
    }
}
