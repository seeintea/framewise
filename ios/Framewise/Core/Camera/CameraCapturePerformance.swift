//
//  CameraCapturePerformance.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/27.
//

import Foundation
import OSLog

/// Records capture-to-save performance on one monotonic timeline per photo.
nonisolated struct CameraCapturePerformance: Sendable {
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
            let milliseconds =
                Double(elapsed.seconds) * 1_000
                + Double(elapsed.attoseconds) / 1_000_000_000_000_000
            Self.logger.debug(
                "[CameraCapture] \(id, privacy: .public) \(stage, privacy: .public) +\(milliseconds, format: .fixed(precision: 1))ms"
            )
        #endif
    }
}
