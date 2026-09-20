//
//  PhotoLibraryWriter.swift
//  Framewise legacy camera snapshot
//
//  Created by Codex on 2026/9/14.
//

import Foundation
@preconcurrency import Photos

struct PhotoLibraryWriter: Sendable {
    nonisolated init() {}

    nonisolated func save(
        _ capture: CameraCaptureResult,
        performanceCapture: CameraPerformance.Capture
    ) async throws {
        let totalTimer = CameraPerformance.startTimer()
        var outcome = "success"
        defer {
            CameraPerformance.record(
                "photo_library_total",
                timer: totalTimer,
                capture: performanceCapture,
                outcome: outcome
            )
        }

        let pairedVideoURL: URL?
        switch capture {
        case .photo:
            pairedVideoURL = nil
        case .livePhoto(_, let url):
            pairedVideoURL = url
        }

        defer {
            if let pairedVideoURL {
                try? FileManager.default.removeItem(at: pairedVideoURL)
            }
        }

        let authorizationTimer = CameraPerformance.startTimer()
        let authorizationStatus = await authorizationStatus()
        CameraPerformance.record(
            "photo_library_authorization",
            timer: authorizationTimer,
            capture: performanceCapture,
            detail: Self.authorizationDetail(authorizationStatus)
        )

        switch authorizationStatus {
        case .authorized, .limited:
            break
        case .denied:
            outcome = "failure"
            throw CameraError.photoLibraryAuthorizationDenied
        case .restricted:
            outcome = "failure"
            throw CameraError.photoLibraryAuthorizationRestricted
        case .notDetermined:
            outcome = "failure"
            throw CameraError.photoLibraryAuthorizationDenied
        @unknown default:
            outcome = "failure"
            throw CameraError.photoLibraryAuthorizationRestricted
        }

        let saveTimer = CameraPerformance.startTimer()
        do {
            switch capture {
            case .photo(let data):
                try await savePhoto(data: data)
            case .livePhoto(let photoData, let pairedVideoURL):
                try await saveLivePhoto(
                    photoData: photoData,
                    pairedVideoURL: pairedVideoURL
                )
            }
            CameraPerformance.record(
                "photo_library_save",
                timer: saveTimer,
                capture: performanceCapture
            )
        } catch {
            outcome = "failure"
            CameraPerformance.record(
                "photo_library_save",
                timer: saveTimer,
                capture: performanceCapture,
                outcome: "failure"
            )
            throw error
        }
    }

    nonisolated private func savePhoto(data: Data) async throws {
        try await performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    nonisolated private func saveLivePhoto(
        photoData: Data,
        pairedVideoURL: URL
    ) async throws {
        try await performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(
                with: .photo,
                data: photoData,
                options: nil
            )

            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true
            request.addResource(
                with: .pairedVideo,
                fileURL: pairedVideoURL,
                options: options
            )
        }
    }

    nonisolated private func performChanges(
        _ changes: @escaping @Sendable () -> Void
    ) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges(changes)
        } catch {
            throw CameraError.photoLibrarySaveFailed(error.localizedDescription)
        }
    }

    nonisolated private func authorizationStatus() async
        -> PHAuthorizationStatus
    {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    nonisolated private static func authorizationDetail(
        _ status: PHAuthorizationStatus
    ) -> String {
        switch status {
        case .notDetermined:
            "not_determined"
        case .restricted:
            "restricted"
        case .denied:
            "denied"
        case .authorized:
            "authorized"
        case .limited:
            "limited"
        @unknown default:
            "unknown"
        }
    }
}
