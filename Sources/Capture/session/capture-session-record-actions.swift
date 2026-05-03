import Foundation

public extension CaptureSession {
    var record: CaptureSessionRecordActions {
        CaptureSessionRecordActions(
            session: self
        )
    }
}

public struct CaptureSessionRecordActions: Sendable {
    public let session: CaptureSession

    public init(
        session: CaptureSession
    ) {
        self.session = session
    }

    public func duration(
        _ duration: CaptureRecordDuration
    ) async throws -> CaptureRecordingResult {
        try await CaptureSession(
            configuration: session.configuration,
            options: CaptureRecordOptions(
                duration: duration
            ),
            workspace: session.workspace,
            deviceProvider: session.deviceProvider,
            microphoneChain: session.microphoneChain,
            progress: session.progress
        ).start()
    }

    public func live(
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureRecordingResult {
        try await session.startUntilStopped(
            stopSignal: stopSignal
        )
    }

    public func mode(
        _ mode: CaptureRecordMode,
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureRecordingResult {
        switch mode {
        case .live:
            return try await live(
                stopSignal: stopSignal
            )

        case .duration(let duration):
            return try await self.duration(
                duration
            )
        }
    }
}

public extension CameraCaptureSession {
    var record: CameraCaptureSessionRecordActions {
        CameraCaptureSessionRecordActions(
            session: self
        )
    }
}

public struct CameraCaptureSessionRecordActions: Sendable {
    public let session: CameraCaptureSession

    public init(
        session: CameraCaptureSession
    ) {
        self.session = session
    }

    public func duration(
        _ duration: CaptureRecordDuration
    ) async throws -> CaptureCameraRecordingResult {
        try await CameraCaptureSession(
            configuration: session.configuration,
            options: CaptureRecordOptions(
                duration: duration
            ),
            workspace: session.workspace,
            deviceProvider: session.deviceProvider,
            microphoneChain: session.microphoneChain,
            progress: session.progress
        ).start()
    }

    public func live(
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureCameraRecordingResult {
        try await session.startUntilStopped(
            stopSignal: stopSignal
        )
    }

    public func mode(
        _ mode: CaptureRecordMode,
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureCameraRecordingResult {
        switch mode {
        case .live:
            return try await live(
                stopSignal: stopSignal
            )

        case .duration(let duration):
            return try await self.duration(
                duration
            )
        }
    }
}

public extension CaptureCompositionSession {
    var record: CaptureCompositionSessionRecordActions {
        CaptureCompositionSessionRecordActions(
            session: self
        )
    }
}

public struct CaptureCompositionSessionRecordActions: Sendable {
    public let session: CaptureCompositionSession

    public init(
        session: CaptureCompositionSession
    ) {
        self.session = session
    }

    public func duration(
        _ duration: CaptureRecordDuration
    ) async throws -> CaptureCompositionRecordingResult {
        try await CaptureCompositionSession(
            configuration: session.configuration,
            options: CaptureRecordOptions(
                duration: duration
            ),
            workspace: session.workspace,
            deviceProvider: session.deviceProvider,
            microphoneChain: session.microphoneChain,
            progress: session.progress
        ).start()
    }

    public func live(
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureCompositionRecordingResult {
        try await session.startUntilStopped(
            stopSignal: stopSignal
        )
    }

    public func mode(
        _ mode: CaptureRecordMode,
        stopSignal: CaptureStopSignal
    ) async throws -> CaptureCompositionRecordingResult {
        switch mode {
        case .live:
            return try await live(
                stopSignal: stopSignal
            )

        case .duration(let duration):
            return try await self.duration(
                duration
            )
        }
    }
}
