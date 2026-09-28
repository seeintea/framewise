import Foundation
import OSLog

/// Session and permission operations are recorded in Debug and Release.
nonisolated struct CameraSessionPerformance: Sendable {
    enum Operation: String, Sendable {
        case permissions
        case startup
        case recovery
        case switchCamera = "switch_camera"
        case livePhoto = "live_photo"
        case stop
    }

    enum Outcome: String, Sendable {
        case success, failure, fallback, cancelled, skipped, interrupted
    }

    private static let logger = Logger(
        subsystem: "com.leviegu.framewise", category: "CameraSession"
    )
    #if DEBUG
        private static let build = "debug"
    #else
        private static let build = "release"
    #endif
    private let id = UUID().uuidString
    private let startedAt = ContinuousClock.now
    private let operation: Operation

    init(operation: Operation) {
        self.operation = operation
        record("begin")
    }

    func record(
        _ phase: String,
        since phaseStart: ContinuousClock.Instant? = nil,
        outcome: Outcome = .success,
        detail: String = "none"
    ) {
        let now = ContinuousClock.now
        let duration = Self.milliseconds((phaseStart ?? startedAt).duration(to: now))
        let elapsed = Self.milliseconds(startedAt.duration(to: now))
        Self.logger.info(
            "[CameraSession] \(id, privacy: .public) build=\(Self.build, privacy: .public) operation=\(operation.rawValue, privacy: .public) phase=\(phase, privacy: .public) duration=\(duration, format: .fixed(precision: 1))ms elapsed=\(elapsed, format: .fixed(precision: 1))ms outcome=\(outcome.rawValue, privacy: .public) detail=\(detail, privacy: .public)"
        )
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
