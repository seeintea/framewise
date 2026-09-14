//
//  CameraError.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

import Foundation

enum CameraError: Error, Equatable, Sendable {
    case authorizationDenied
    case authorizationRestricted
    case noCameraAvailable
    case cannotCreateInput(String)
    case cannotAddInput
    case cannotAddPhotoOutput
    case cannotStartSession
    case captureNotReady
    case captureFailed(String)
    case photoDataUnavailable
    case processingFailed(String)
    case photoLibraryAuthorizationDenied
    case photoLibraryAuthorizationRestricted
    case photoLibrarySaveFailed(String)
    case runtimeError(String)

    var canRetry: Bool {
        switch self {
        case .authorizationDenied,
             .authorizationRestricted,
             .photoLibraryAuthorizationDenied,
             .photoLibraryAuthorizationRestricted:
            false
        case .noCameraAvailable:
            true
        case .cannotCreateInput,
             .cannotAddInput,
             .cannotAddPhotoOutput,
             .cannotStartSession,
             .captureNotReady,
             .captureFailed,
             .photoDataUnavailable,
             .processingFailed,
             .photoLibrarySaveFailed,
             .runtimeError:
            true
        }
    }

    var settingsCanResolve: Bool {
        switch self {
        case .authorizationDenied,
             .authorizationRestricted,
             .photoLibraryAuthorizationDenied,
             .photoLibraryAuthorizationRestricted:
            true
        default:
            false
        }
    }
}
