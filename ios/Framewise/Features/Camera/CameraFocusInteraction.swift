//
//  CameraFocusInteraction.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import SwiftUI

/// Point-focus behavior backed by the camera page's local value state.
/// Hiding feedback preserves the device selection; clearing it invalidates its callbacks.
struct CameraFocusInteraction {
    struct State {
        var point: CGPoint?
        var exposureBias: Double = 0
        var selectionID: UUID?
        var pendingResetID: UUID?
        var isResetting = false
        var feedbackTask: Task<Void, Never>?
        var isDimmed = false
        var isExposureInteractionActive = false
    }

    @Binding private var state: State
    private let camera: CameraController
    private let canInteract: () -> Bool
    private let configurationID: () -> UUID
    private let isRunning: () -> Bool
    private let reduceMotion: Bool
    private let onError: (LocalizedStringResource) -> Void

    init(
        state: Binding<State>,
        camera: CameraController,
        canInteract: @escaping () -> Bool,
        configurationID: @escaping () -> UUID,
        isRunning: @escaping () -> Bool,
        reduceMotion: Bool,
        onError: @escaping (LocalizedStringResource) -> Void
    ) {
        self._state = state
        self.camera = camera
        self.canInteract = canInteract
        self.configurationID = configurationID
        self.isRunning = isRunning
        self.reduceMotion = reduceMotion
        self.onError = onError
    }

    var point: CGPoint? { state.point }
    var exposureBias: Double { state.exposureBias }
    var isResetting: Bool { state.isResetting }
    var feedbackOpacity: Double { state.isDimmed ? 0.5 : 1 }

    func applyExposureBias(_ bias: Float) {
        state.exposureBias = Double(bias)
    }

    func hideFeedback() {
        state.point = nil
    }

    func focus(at devicePoint: CGPoint, showAt viewPoint: CGPoint) {
        guard canInteract() else { return }
        let selectionID = UUID()
        state.selectionID = selectionID
        state.pendingResetID = nil
        state.isResetting = false
        state.isDimmed = false
        state.point = viewPoint
        scheduleFeedbackTimeout()
        let configurationID = configurationID()
        camera.focusAndExpose(
            at: devicePoint,
            onSceneChange: {
                guard isRunning(), self.configurationID() == configurationID,
                    state.selectionID == selectionID
                else { return }
                state.pendingResetID = selectionID
                resetForSceneChangeIfNeeded()
            },
            completion: { result in
                guard isRunning(), self.configurationID() == configurationID,
                    state.selectionID == selectionID
                else { return }
                switch result {
                case .success:
                    state.exposureBias = 0
                case .failure:
                    clear()
                    onError(.cameraErrorFocus)
                }
            }
        )
    }

    func resetForSceneChangeIfNeeded() {
        guard let selectionID = state.pendingResetID, state.selectionID == selectionID else {
            return
        }
        guard canInteract(), !state.isExposureInteractionActive, !state.isResetting else { return }
        state.pendingResetID = nil
        state.isResetting = true
        state.feedbackTask?.cancel()
        let configurationID = configurationID()
        camera.focusAndExpose(at: CGPoint(x: 0.5, y: 0.5)) { result in
            guard isRunning(), self.configurationID() == configurationID,
                state.selectionID == selectionID
            else { return }
            state.isResetting = false
            switch result {
            case .success:
                clear()
                state.exposureBias = 0
            case .failure:
                scheduleFeedbackTimeout()
                onError(.cameraErrorFocus)
            }
        }
    }

    func setExposureBias(_ requestedBias: Double) {
        guard canInteract(), !state.isResetting else { return }
        let selectionID = state.selectionID
        state.exposureBias = requestedBias
        let configurationID = configurationID()
        camera.setExposureBias(Float(requestedBias)) { result in
            guard isRunning(), self.configurationID() == configurationID,
                state.selectionID == selectionID
            else { return }
            switch result {
            case .success(let value): state.exposureBias = Double(value)
            case .failure: onError(.cameraErrorExposure)
            }
        }
    }

    func setExposureInteractionActive(_ active: Bool) {
        state.isExposureInteractionActive = active
        if active {
            state.feedbackTask?.cancel()
            state.isDimmed = false
        } else if state.pendingResetID != nil {
            resetForSceneChangeIfNeeded()
        } else {
            scheduleFeedbackTimeout()
        }
    }

    func clear() {
        camera.stopMonitoringFocusMovement()
        state.selectionID = nil
        state.pendingResetID = nil
        state.isResetting = false
        state.feedbackTask?.cancel()
        state.point = nil
        state.isDimmed = false
        state.isExposureInteractionActive = false
    }

    func end() {
        if state.selectionID != nil {
            camera.focusAndExpose(at: CGPoint(x: 0.5, y: 0.5)) { result in
                if case .failure(let error) = result {
                    print("Camera: could not restore automatic focus: \(error)")
                }
            }
        }
        clear()
    }

    private func scheduleFeedbackTimeout() {
        state.feedbackTask?.cancel()
        state.feedbackTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled, !state.isExposureInteractionActive, state.point != nil
            else { return }
            if state.exposureBias == 0 {
                hideFeedback()
            } else {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    state.isDimmed = true
                }
            }
        }
    }
}
