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
    @AppStorage("camera.livePhotoEnabled") private var livePhotoEnabled = false

    let masks: [MaskContent]
    let initialMaskId: String

    @State private var state = State.checking
    @State private var showsPermissionAlert = false

    var body: some View {
        Group {
            switch state {
            case .authorized:
                CameraScreen(
                    masks: masks,
                    initialMaskId: initialMaskId,
                    requestMicrophoneAccess: requestMicrophoneAccess,
                    livePhotoEnabled: $livePhotoEnabled
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
                if livePhotoEnabled {
                    Button(.cameraLiveDisable) { disableLivePhotoPreference() }
                }
                Button(.cameraAccessActionCancel, role: .cancel) {}

            case .denied:
                Button(.cameraAccessActionOpenSettings) {
                    openSettings()
                }
                if livePhotoEnabled {
                    Button(.cameraLiveDisable) { disableLivePhotoPreference() }
                }
                Button(.cameraAccessActionCancel, role: .cancel) {}

            case .restricted:
                if livePhotoEnabled {
                    Button(.cameraLiveDisable) { disableLivePhotoPreference() }
                }
                Button(.cameraAccessActionAcknowledge, role: .cancel) {}

            case .unavailable:
                Button(.cameraAccessActionRetry) {
                    reloadStatus()
                }
                if livePhotoEnabled {
                    Button(.cameraLiveDisable) { disableLivePhotoPreference() }
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
        guard state == .notDetermined else { return }
        let permissions = requiredPermissions
        state = .requesting
        showsPermissionAlert = false

        Task {
            for permission in permissions {
                let result = await Permissions.request([permission])
                guard result[permission].isAuthorized else { break }
            }

            reloadStatus()
        }
    }

    private func reloadStatus() {
        let permissions = requiredPermissions
        state = State(
            result: Permissions.check(permissions),
            permissions: permissions
        )
        showsPermissionAlert = state.needsGuidance
    }

    private func openSettings() {
        Task {
            await Permissions.openSettings()
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        let result = await Permissions.request([.microphone])
        return result.isAuthorized
    }

    private func disableLivePhotoPreference() {
        livePhotoEnabled = false
        reloadStatus()
    }

    private var requiredPermissions: [Permissions.Kind] {
        livePhotoEnabled ? [.camera, .photoLibraryAdd, .microphone]
            : [.camera, .photoLibraryAdd]
    }

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

private extension CameraAccess {
    enum State: Equatable {
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
