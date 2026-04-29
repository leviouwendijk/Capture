import Foundation

enum CaptureCLIError: Error, LocalizedError {
    case missing(String)
    case invalidQuality(value: String, allowed: [String])
    case invalidAudioLayout(value: String, allowed: [String])

    var errorDescription: String? {
        switch self {
        case .missing(let message):
            return message

        case .invalidQuality(let value, let allowed):
            return "Invalid quality preset: \(value). Expected one of: \(allowed.joined(separator: ", "))."

        case .invalidAudioLayout(let value, let allowed):
            return "Invalid audio layout: \(value). Expected one of: \(allowed.joined(separator: ", "))."
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
