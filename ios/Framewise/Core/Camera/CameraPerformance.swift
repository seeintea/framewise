//
//  CameraPerformance.swift
//  Framewise
//
//  Created by Codex on 2026/9/15.
//

import Foundation
import OSLog

nonisolated enum CameraPerformance {
    struct Timer: Sendable {
        fileprivate let startedAt: ContinuousClock.Instant
    }

    struct Capture: Sendable {
        let id: String
        let kind: String
        let requestTimer: Timer
    }

    private static let logger = Logger(
        subsystem: "com.leviegu.framewise",
        category: "CameraPerformance"
    )

    static func startTimer() -> Timer {
        Timer(startedAt: .now)
    }

    static func startCapture(isLivePhoto: Bool) -> Capture {
        Capture(
            id: UUID().uuidString,
            kind: isLivePhoto ? "live_photo" : "photo",
            requestTimer: startTimer()
        )
    }

    static func record(
        _ phase: String,
        timer: Timer,
        capture: Capture? = nil,
        outcome: String = "success",
        detail: String = "none"
    ) {
        let duration = timer.startedAt.duration(to: .now)
        let components = duration.components
        let milliseconds = Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
        let operationID = capture?.id ?? "none"
        let captureKind = capture?.kind ?? "none"

        logger.info(
            "camera_metric phase=\(phase, privacy: .public) duration_ms=\(milliseconds, format: .fixed(precision: 2)) outcome=\(outcome, privacy: .public) detail=\(detail, privacy: .public) operation_id=\(operationID, privacy: .public) capture_kind=\(captureKind, privacy: .public)"
        )
    }
}
