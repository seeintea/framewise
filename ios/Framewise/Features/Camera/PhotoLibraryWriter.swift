//
//  PhotoLibraryWriter.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

import Foundation
@preconcurrency import Photos

struct PhotoLibraryWriter: Sendable {
    nonisolated init() {}

    nonisolated func save(_ capture: CameraCaptureResult) async throws {
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

        let authorizationStatus = await authorizationStatus()

        switch authorizationStatus {
        case .authorized, .limited:
            break
        case .denied:
            throw CameraError.photoLibraryAuthorizationDenied
        case .restricted:
            throw CameraError.photoLibraryAuthorizationRestricted
        case .notDetermined:
            throw CameraError.photoLibraryAuthorizationDenied
        @unknown default:
            throw CameraError.photoLibraryAuthorizationRestricted
        }

        switch capture {
        case .photo(let data):
            try await savePhoto(data: data)
        case .livePhoto(let photoData, let pairedVideoURL):
            try await saveLivePhoto(
                photoData: photoData,
                pairedVideoURL: pairedVideoURL
            )
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
}
