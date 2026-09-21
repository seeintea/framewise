//
//  PhotoLibraryPermission.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/21.
//

@preconcurrency import Photos

nonisolated enum PhotoLibraryPermission {
    enum AccessLevel: Sendable {
        case addOnly
        case readWrite
    }

    static func status(for accessLevel: AccessLevel) -> PermissionStatus {
        PermissionStatus(
            PHPhotoLibrary.authorizationStatus(for: accessLevel.photoKitValue)
        )
    }

    static func isAuthorized(for accessLevel: AccessLevel) -> Bool {
        status(for: accessLevel).isAuthorized
    }

    static func request(for accessLevel: AccessLevel) async -> PermissionStatus {
        let currentStatus = status(for: accessLevel)
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(
                for: accessLevel.photoKitValue
            ) { status in
                continuation.resume(returning: PermissionStatus(status))
            }
        }
    }
}

private extension PhotoLibraryPermission.AccessLevel {
    nonisolated var photoKitValue: PHAccessLevel {
        switch self {
        case .addOnly:
            .addOnly
        case .readWrite:
            .readWrite
        }
    }
}

private extension PermissionStatus {
    nonisolated init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .limited:
            self = .limited
        @unknown default:
            self = .unknown
        }
    }
}
