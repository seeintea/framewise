import Foundation
import OSLog

/// One monotonic timeline from the shutter command through PhotoKit's completion.
nonisolated struct CameraCaptureTiming: Sendable {
    #if DEBUG
        private static let logger = Logger(
            subsystem: "com.leviegu.framewise",
            category: "CameraCapture"
        )
        private let id = UUID().uuidString
        private let start = ContinuousClock.now
    #endif

    func record(_ stage: String) {
        #if DEBUG
            let elapsed = start.duration(to: .now).components
            let milliseconds = Double(elapsed.seconds) * 1_000
                + Double(elapsed.attoseconds) / 1_000_000_000_000_000
            Self.logger.debug(
                "[CameraCapture] \(id, privacy: .public) \(stage, privacy: .public) +\(milliseconds, format: .fixed(precision: 1))ms"
            )
        #endif
    }
}
