//
//  PermissionStatus.swift
//  Framewise
//
//  App-facing authorization states shared by individual system permissions.
//

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
