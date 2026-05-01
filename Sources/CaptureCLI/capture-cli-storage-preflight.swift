import Capture
import Foundation

internal enum CaptureCLIStorageMode {
    case record
    case camera
    case composition
}

internal enum CaptureCLIStoragePreflight {
    static let minimumLiveBytes: Int64 = 2 * 1024 * 1024 * 1024
    static let fixedSafetyBytes: Int64 = 512 * 1024 * 1024

    static func ensureAvailable(
        output: URL,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        video: CaptureResolvedVideoOptions,
        durationSeconds: Int?,
        mode: CaptureCLIStorageMode
    ) throws {
        let requiredBytes = requiredBytes(
            video: video,
            durationSeconds: durationSeconds,
            mode: mode
        )

        try ensureAvailable(
            at: output.deletingLastPathComponent(),
            requiredBytes: requiredBytes,
            label: "output"
        )

        try ensureAvailable(
            at: temporaryDirectory,
            requiredBytes: requiredBytes,
            label: "temporary"
        )
    }
}

private extension CaptureCLIStoragePreflight {
    static func requiredBytes(
        video: CaptureResolvedVideoOptions,
        durationSeconds: Int?,
        mode: CaptureCLIStorageMode
    ) -> Int64 {
        guard let durationSeconds else {
            return minimumLiveBytes
        }

        let seconds = max(
            1,
            durationSeconds
        )

        let videoBytesPerSecond = Double(
            video.bitrate
        ) / 8.0

        let videoMultiplier: Double

        switch mode {
        case .record:
            videoMultiplier = 2.5

        case .camera:
            videoMultiplier = 2.5

        case .composition:
            videoMultiplier = 4.5
        }

        let estimatedVideoBytes = videoBytesPerSecond
            * Double(
                seconds
            )
            * videoMultiplier

        let estimatedBytes = Int64(
            estimatedVideoBytes.rounded(
                .up
            )
        ) + fixedSafetyBytes

        return max(
            fixedSafetyBytes,
            estimatedBytes
        )
    }

    static func ensureAvailable(
        at directory: URL,
        requiredBytes: Int64,
        label: String
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        guard let availableBytes = availableBytes(
            at: directory
        ) else {
            return
        }

        guard availableBytes >= requiredBytes else {
            throw CaptureError.videoCapture(
                """
                Insufficient free disk space on \(label) volume.
                required: \(byteDescription(requiredBytes))
                available: \(byteDescription(availableBytes))
                path: \(directory.path)
                """
            )
        }
    }

    static func availableBytes(
        at directory: URL
    ) -> Int64? {
        if let values = try? directory.resourceValues(
            forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
            ]
        ),
        let available = values.volumeAvailableCapacityForImportantUsage {
            return available
        }

        guard let attributes = try? FileManager.default.attributesOfFileSystem(
            forPath: directory.path
        ),
        let freeSize = attributes[.systemFreeSize] as? NSNumber else {
            return nil
        }

        return freeSize.int64Value
    }

    static func byteDescription(
        _ bytes: Int64
    ) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [
            .useMB,
            .useGB,
            .useTB,
        ]
        formatter.countStyle = .file
        formatter.includesActualByteCount = true

        return formatter.string(
            fromByteCount: bytes
        )
    }
}
