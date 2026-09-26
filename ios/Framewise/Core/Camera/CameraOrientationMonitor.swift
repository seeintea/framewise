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
    private var monitoringID = UUID()
    private var lastReliableHold: Hold?
    private var lastLandscapeHold: Hold?
    private var focusReference: (rotation: CMRotationMatrix, timestamp: TimeInterval)?
    private var onFocusMovement: (() -> Void)?
    private static let focusMovementCosine = cos(30 * Double.pi / 180)
    var onHoldChange: ((Int) -> Void)?

    func start() {
        guard orientationObserver == nil else { return }
        let operationID = UUID()
        monitoringID = operationID
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        rememberDeviceOrientation()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.monitoringID == operationID else { return }
                self.rememberDeviceOrientation()
            }
        }
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let self, let sample else { return }
            let x = sample.gravity.x
            let y = sample.gravity.y
            let rotation = sample.attitude.rotationMatrix
            let timestamp = sample.timestamp
            Task { @MainActor in
                guard self.monitoringID == operationID else { return }
                self.rememberGravity(x: x, y: y)
                self.checkFocusMovement(rotation: rotation, timestamp: timestamp)
            }
        }
    }

    func stop() {
        monitoringID = UUID()
        stopMonitoringFocusMovement()
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
            self.orientationObserver = nil
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        motion.stopDeviceMotionUpdates()
    }

    func monitorFocusMovement(onChange: @escaping () -> Void) {
        stopMonitoringFocusMovement()
        guard motion.isDeviceMotionActive else { return }
        onFocusMovement = onChange
        if let sample = motion.deviceMotion {
            focusReference = (sample.attitude.rotationMatrix, sample.timestamp)
        }
    }

    func stopMonitoringFocusMovement() {
        focusReference = nil
        onFocusMovement = nil
    }

    private func checkFocusMovement(rotation: CMRotationMatrix, timestamp: TimeInterval) {
        guard let onChange = onFocusMovement else { return }
        guard let reference = focusReference else {
            focusReference = (rotation, timestamp)
            return
        }
        // A queued sample from before the latest tap cannot move its reference.
        guard timestamp > reference.timestamp else { return }
        let cosine = Self.viewingDirectionCosine(between: reference.rotation, and: rotation)
        guard cosine <= Self.focusMovementCosine else { return }
        stopMonitoringFocusMovement()
        onChange()
    }

    private static func viewingDirectionCosine(
        between reference: CMRotationMatrix,
        and current: CMRotationMatrix
    ) -> Double {
        // Core Motion maps reference coordinates into device coordinates. Its third
        // row is the device Z axis in the reference frame: camera roll leaves it unchanged.
        reference.m31 * current.m31
            + reference.m32 * current.m32
            + reference.m33 * current.m33
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
        if hold != lastReliableHold { onHoldChange?(hold.quarterTurns) }
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
        guard let hold = deviceHold() else { return }
        if currentGravityHold() == nil, hold != lastReliableHold {
            onHoldChange?(hold.quarterTurns)
        }
        if hold != .portrait { lastLandscapeHold = hold }
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
