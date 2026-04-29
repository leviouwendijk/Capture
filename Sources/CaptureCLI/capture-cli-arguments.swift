import Foundation

enum CaptureCLIError: Error, LocalizedError {
    case missing(String)

    var errorDescription: String? {
        switch self {
        case .missing(let message):
            return message
        }
    }
}

extension Optional {
    func unwrap(
        message: String
    ) throws -> Wrapped {
        guard let value = self else {
            throw CaptureCLIError.missing(
                message
            )
        }

        return value
    }
}

extension String {
    func expandingTilde() -> String {
        guard hasPrefix("~/") else {
            return self
        }

        return FileManager.default.homeDirectoryForCurrentUser.path
            + "/"
            + dropFirst(2)
    }
}
