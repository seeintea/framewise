//
//  Permissions.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/21.
//

import UIKit

nonisolated enum PermissionStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
    case unknown

    var isAuthorized: Bool {
        switch self {
        case .authorized, .limited:
            true
        case .notDetermined, .denied, .restricted, .unknown:
            false
        }
    }
}

nonisolated enum Permissions {
    enum Kind: Hashable, Sendable {
        case camera
        case photoLibraryAdd
        case photoLibraryRead
        case microphone
    }

    struct CheckResult: Equatable, Sendable {
        private let statuses: [Kind: PermissionStatus]

        var isAuthorized: Bool {
            !statuses.isEmpty && statuses.values.allSatisfy(\.isAuthorized)
        }

        subscript(_ permission: Kind) -> PermissionStatus {
            statuses[permission] ?? .unknown
        }

        fileprivate init(statuses: [Kind: PermissionStatus]) {
            self.statuses = statuses
        }
    }

    static func check(_ permissions: [Kind]) -> CheckResult {
        CheckResult(
            statuses: Dictionary(
                uniqueKeysWithValues: unique(permissions).map { permission in
                    (permission, permission.status)
                }
            )
        )
    }

    static func request(_ permissions: [Kind]) async -> CheckResult {
        var results: [Kind: PermissionStatus] = [:]

        for permission in unique(permissions) {
            results[permission] = await permission.request()
        }

        return CheckResult(statuses: results)
    }

    @MainActor
    @discardableResult
    static func openSettings() async -> Bool {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return false
        }

        return await UIApplication.shared.open(url)
    }

    private static func unique(_ permissions: [Kind]) -> [Kind] {
        var seen: Set<Kind> = []
        return permissions.filter { seen.insert($0).inserted }
    }
}

private extension Permissions.Kind {
    nonisolated var status: PermissionStatus {
        switch self {
        case .camera:
            CameraPermission.status
        case .photoLibraryAdd:
            PhotoLibraryPermission.status(for: .addOnly)
        case .photoLibraryRead:
            PhotoLibraryPermission.status(for: .readWrite)
        case .microphone:
            MicrophonePermission.status
        }
    }

    nonisolated func request() async -> PermissionStatus {
        switch self {
        case .camera:
            await CameraPermission.request()
        case .photoLibraryAdd:
            await PhotoLibraryPermission.request(for: .addOnly)
        case .photoLibraryRead:
            await PhotoLibraryPermission.request(for: .readWrite)
        case .microphone:
            await MicrophonePermission.request()
        }
    }
}
