//
//  CameraOrientationMonitor.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import CoreMotion
import UIKit

@MainActor
final class CameraOrientationMonitor {
    private enum Hold: Equatable {
        case portrait
        case landscapeLeft
        case landscapeRight

        var quarterTurns: Int {
            switch self {
            case .portrait: 0
            case .landscapeLeft: -1
            case .landscapeRight: 1
            }
        }
    }

    private let motion = CMMotionManager()
    private var orientationObserver: NSObjectProtocol?
    private var lastReliableHold: Hold?
    private var lastLandscapeHold: Hold?

    func start() {
        guard orientationObserver == nil else { return }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        rememberDeviceOrientation()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.rememberDeviceOrientation() }
        }
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let self, let sample else { return }
            let x = sample.gravity.x
            let y = sample.gravity.y
            Task { @MainActor in self.rememberGravity(x: x, y: y) }
        }
    }

    func stop() {
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
            self.orientationObserver = nil
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        motion.stopDeviceMotionUpdates()
    }

    func quarterTurns(for ratio: PhotoAspectRatio) -> Int {
        if ratio.isLandscapeOutput {
            if let hold = currentGravityHold(), hold != .portrait {
                return hold.quarterTurns
            }
            if let hold = deviceHold(), hold != .portrait {
                return hold.quarterTurns
            }
            return lastLandscapeHold?.quarterTurns ?? -1
        }
        guard ratio == .square else { return 0 }
        return (currentGravityHold() ?? lastReliableHold ?? deviceHold())?
            .quarterTurns ?? 0
    }

    private func rememberGravity(x: Double, y: Double) {
        guard let hold = Self.hold(x: x, y: y) else { return }
        lastReliableHold = hold
        if hold != .portrait { lastLandscapeHold = hold }
    }

    private func currentGravityHold() -> Hold? {
        guard let gravity = motion.deviceMotion?.gravity else { return nil }
        return Self.hold(x: gravity.x, y: gravity.y)
    }

    private static func hold(x: Double, y: Double) -> Hold? {
        if abs(x) >= 0.5, abs(x) > abs(y) {
            return x < 0 ? .landscapeLeft : .landscapeRight
        }
        if abs(y) >= 0.5, abs(y) > abs(x) { return .portrait }
        return nil
    }

    private func rememberDeviceOrientation() {
        if let hold = deviceHold(), hold != .portrait {
            lastLandscapeHold = hold
        }
    }

    private func deviceHold() -> Hold? {
        switch UIDevice.current.orientation {
        case .portrait: .portrait
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        default: nil
        }
    }
}
