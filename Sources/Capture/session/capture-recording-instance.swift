import Foundation

internal enum CaptureRecordingInstance {
    internal enum workspace {
        internal static func create(
            prefix: String
        ) throws -> URL {
            let workingDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "\(prefix)-\(UUID().uuidString)",
                    isDirectory: true
                )

            try FileManager.default.createDirectory(
                at: workingDirectory,
                withIntermediateDirectories: true
            )

            return workingDirectory
        }

        internal static func remove<Result>(
            _ workingDirectory: URL,
            operation: () async throws -> Result
        ) async throws -> Result {
            var shouldRemoveWorkingDirectory = false

            defer {
                if shouldRemoveWorkingDirectory {
                    try? FileManager.default.removeItem(
                        at: workingDirectory
                    )
                }
            }

            let result = try await operation()

            shouldRemoveWorkingDirectory = true

            return result
        }
    }

    internal enum execute {
        internal static func errorcatch<Result>(
            workdir: URL,
            operation: () async throws -> Result
        ) async throws -> Result {
            do {
                return try await operation()
            } catch {
                throw CapturePartialRecordingError(
                    workingDirectory: workdir,
                    underlyingError: error
                )
            }
        }

        internal static func attempt<Result>(
            prefix: String,
            operation: (URL) async throws -> Result
        ) async throws -> Result {
            let workdir = try workspace.create(
                prefix: prefix
            )

            return try await errorcatch(
                workdir: workdir
            ) {
                try await workspace.remove(
                    workdir
                ) {
                    try await operation(
                        workdir
                    )
                }
            }
        }
    }
}
