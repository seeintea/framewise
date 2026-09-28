//
//  CameraAccess.swift
//  Framewise
//
//  Gates the camera feature behind explicit camera permission handling.
//
//  Created by yukkuri on 2026/9/21.
//

import SwiftUI

struct CameraAccess: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("camera.livePhotoEnabled") private var prefersLivePhoto = false

    let masks: [MaskContent]
    let initialMaskId: String

    @State private var state = State.checking
    @State private var showsPermissionAlert = false
    @State private var permissionRequestID = UUID()
    @State private var permissionRequestTask: Task<Void, Never>?

    var body: some View {
        Group {
            switch state {
            case .authorized:
                CameraScreen(
                    masks: masks,
                    initialMaskId: initialMaskId,
                    requestMicrophoneAccess: requestMicrophoneAccess,
                    prefersLivePhoto: $prefersLivePhoto
                )

            case .requesting:
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel(
                            Text(.cameraAccessRequestingAccessibilityLabel)
                        )
                }

            case .checking, .notDetermined, .denied, .restricted,
                .unavailable:
                Color.black
                    .ignoresSafeArea()
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            reloadStatus()
        }
        .onDisappear {
            permissionRequestID = UUID()
            permissionRequestTask?.cancel()
            permissionRequestTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, state != .requesting else { return }
            reloadStatus()
        }
        .alert(alertTitle, isPresented: $showsPermissionAlert) {
            switch state {
            case .notDetermined:
                Button(.cameraAccessActionContinue) {
                    requestAccess()
                }
                Button(.cameraAccessActionCancel, role: .cancel) {}

            case .denied:
                Button(.cameraAccessActionOpenSettings) {
                    openSettings()
                }
                Button(.cameraAccessActionCancel, role: .cancel) {}

            case .restricted:
                Button(.cameraAccessActionAcknowledge, role: .cancel) {}

            case .unavailable:
                Button(.cameraAccessActionRetry) {
                    reloadStatus()
                }
                Button(.cameraAccessActionCancel, role: .cancel) {}

            case .checking, .requesting, .authorized:
                EmptyView()
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func requestAccess() {
        guard state == .notDetermined || state == .authorized else { return }
        let performance = CameraSessionPerformance(operation: .permissions)
        let requestID = UUID()
        permissionRequestID = requestID
        state = .requesting
        showsPermissionAlert = false
        permissionRequestTask = Task {
            var outcome = CameraSessionPerformance.Outcome.success
            defer { performance.record("permissions_total", outcome: outcome) }
            for permission in requiredPermissions {
                let result = await request(permission, performance: performance)
                guard !Task.isCancelled, permissionRequestID == requestID else {
                    outcome = .cancelled
                    return
                }
                if !result.isAuthorized {
                    outcome = .failure
                    break
                }
            }
            if Permissions.check(requiredPermissions).isAuthorized, prefersLivePhoto {
                let microphone = await request(.microphone, performance: performance)
                guard !Task.isCancelled, permissionRequestID == requestID else {
                    outcome = .cancelled
                    return
                }
                if !microphone.isAuthorized { outcome = .fallback }
            }
            permissionRequestTask = nil
            reloadStatus()
        }
    }

    private func reloadStatus() {
        let performance = CameraSessionPerformance(operation: .permissions)
        let start = ContinuousClock.now
        let result = Permissions.check(requiredPermissions)
        state = State(result: result, permissions: requiredPermissions)
        let microphone = prefersLivePhoto ? Permissions.check([.microphone])[.microphone] : nil
        performance.record(
            "permission_check", since: start,
            outcome: result.isAuthorized ? .success : .failure,
            detail:
                "camera=\(result[.camera]) photos=\(result[.photoLibraryAdd]) microphone=\(microphone.map { String(describing: $0) } ?? "not_requested")"
        )
        showsPermissionAlert = state.needsGuidance
        if state == .authorized, prefersLivePhoto, microphone == .notDetermined {
            performance.record(
                "permissions_total", outcome: .skipped, detail: "microphone_request_needed")
            requestAccess()
        } else {
            let outcome: CameraSessionPerformance.Outcome =
                !result.isAuthorized
                ? .failure
                : prefersLivePhoto && microphone?.isAuthorized != true ? .fallback : .success
            performance.record("permissions_total", outcome: outcome)
        }
    }

    private func openSettings() {
        Task { await Permissions.openSettings() }
    }

    private func requestMicrophoneAccess() async -> Bool {
        let performance = CameraSessionPerformance(operation: .permissions)
        let result = await request(.microphone, performance: performance)
        performance.record("permissions_total", outcome: result.isAuthorized ? .success : .fallback)
        return result.isAuthorized
    }

    private func request(
        _ permission: Permissions.Kind, performance: CameraSessionPerformance
    ) async -> PermissionStatus {
        let start = ContinuousClock.now
        let result = await Permissions.request([permission])[permission]
        performance.record(
            "permission_request", since: start,
            outcome: result.isAuthorized
                ? .success : permission == .microphone ? .fallback : .failure,
            detail: "\(permission)=\(result)"
        )
        return result
    }

    // The microphone is optional: unavailable Live Photo must not block still photography.
    private var requiredPermissions: [Permissions.Kind] { [.camera, .photoLibraryAdd] }

    private var alertTitle: LocalizedStringResource {
        switch state {
        case .notDetermined:
            .cameraAccessAlertRequestTitle
        case .denied:
            .cameraAccessAlertDeniedTitle
        case .restricted:
            .cameraAccessAlertRestrictedTitle
        case .unavailable:
            .cameraAccessAlertUnavailableTitle
        case .checking, .requesting, .authorized:
            ""
        }
    }

    private var alertMessage: LocalizedStringResource {
        switch state {
        case .notDetermined:
            .cameraAccessAlertRequestPhotoMessage
        case .denied:
            .cameraAccessAlertDeniedMessage
        case .restricted:
            .cameraAccessAlertRestrictedMessage
        case .unavailable:
            .cameraAccessAlertUnavailableMessage
        case .checking, .requesting, .authorized:
            ""
        }
    }
}

extension CameraAccess {
    fileprivate enum State: Equatable {
        case checking
        case notDetermined
        case requesting
        case authorized
        case denied
        case restricted
        case unavailable

        init(
            result: Permissions.CheckResult,
            permissions: [Permissions.Kind]
        ) {
            if result.isAuthorized {
                self = .authorized
            } else if permissions.contains(where: {
                result[$0] == .restricted
            }) {
                self = .restricted
            } else if permissions.contains(where: {
                result[$0] == .denied
            }) {
                self = .denied
            } else if permissions.contains(where: {
                result[$0] == .unknown
            }) {
                self = .unavailable
            } else {
                self = .notDetermined
            }
        }

        var needsGuidance: Bool {
            switch self {
            case .notDetermined, .denied, .restricted, .unavailable:
                true
            case .checking, .requesting, .authorized:
                false
            }
        }
    }
}
