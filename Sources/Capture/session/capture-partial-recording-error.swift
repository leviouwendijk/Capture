import Foundation

public struct CapturePartialRecordingError: Error, Sendable, LocalizedError {
    public let workingDirectory: URL
    public let retainedFiles: [URL]
    public let underlyingErrorDescription: String

    public init(
        workingDirectory: URL,
        retainedFiles: [URL],
        underlyingErrorDescription: String
    ) {
        self.workingDirectory = workingDirectory
        self.retainedFiles = retainedFiles
        self.underlyingErrorDescription = underlyingErrorDescription
    }

    public init(
        workingDirectory: URL,
        underlyingError: Error
    ) {
        self.init(
            workingDirectory: workingDirectory,
            retainedFiles: Self.files(
                in: workingDirectory
            ),
            underlyingErrorDescription: underlyingError.localizedDescription
        )
    }

    public var errorDescription: String? {
        "Recording failed before final export. Partial recording files were retained."
    }

    public var failureReason: String? {
        underlyingErrorDescription
    }
}

private extension CapturePartialRecordingError {
    static func files(
        in directory: URL
    ) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
            ]
        ) else {
            return []
        }

        return enumerator
            .compactMap {
                $0 as? URL
            }
            .filter {
                isRegularFile(
                    $0
                )
            }
            .sorted {
                $0.path.localizedStandardCompare(
                    $1.path
                ) == .orderedAscending
            }
    }

    static func isRegularFile(
        _ url: URL
    ) -> Bool {
        (
            try? url.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                ]
            ).isRegularFile
        ) == true
    }
}
