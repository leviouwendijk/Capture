import Foundation

internal enum CaptureRecordingInstance {
    internal enum workspace {
        internal static func create(
            prefix: String,
            options: CaptureWorkspaceOptions = .standard
        ) throws -> URL {
            let root = options.resolvedRoot

            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )

            let workingDirectory = root.appendingPathComponent(
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
            workspace options: CaptureWorkspaceOptions = .standard,
            operation: (URL) async throws -> Result
        ) async throws -> Result {
            let workdir = try workspace.create(
                prefix: prefix,
                options: options
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
