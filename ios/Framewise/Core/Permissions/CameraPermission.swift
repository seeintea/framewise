//
//  CameraPermission.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/21.
//

@preconcurrency import AVFoundation

nonisolated enum CameraPermission {
    static var status: PermissionStatus {
        PermissionStatus(AVCaptureDevice.authorizationStatus(for: .video))
    }

    static var isAuthorized: Bool {
        status.isAuthorized
    }

    static func request() async -> PermissionStatus {
        let currentStatus = status
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { _ in
                continuation.resume(returning: status)
            }
        }
    }
}

private extension PermissionStatus {
    nonisolated init(_ status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        @unknown default:
            self = .unknown
        }
    }
}
