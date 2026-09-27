//
//  CameraPhotoSaver.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import Photos

extension Notification.Name {
    static let cameraPhotoSaveFailed = Notification.Name(
        "cameraPhotoSaveFailed"
    )
}

/// Owns processing and library writes after the capture delegate has released the shutter.
actor CameraPhotoSaver {
    static let shared = CameraPhotoSaver()

    private let livePhotoProcessor = LivePhotoProcessor()

    nonisolated func enqueue(
        _ captured: CameraEngine.CapturedPhoto,
        ratio: PhotoAspectRatio,
        quarterTurns: Int,
        performance: CameraCapturePerformance
    ) {
        // The shared saver owns this user-requested work beyond the camera page's lifetime.
        Task.detached(priority: .userInitiated) { [self] in
            do {
                try await save(
                    captured,
                    ratio: ratio,
                    quarterTurns: quarterTurns,
                    performance: performance
                )
            } catch {
                performance.record("saveFailed")
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .cameraPhotoSaveFailed,
                        object: nil
                    )
                }
            }
        }
    }

    private func save(
        _ captured: CameraEngine.CapturedPhoto,
        ratio: PhotoAspectRatio,
        quarterTurns: Int,
        performance: CameraCapturePerformance
    ) async throws {
        performance.record("saveStarted")
        switch captured {
        case .still(let data):
            let processedPhoto = try await CameraPhotoProcessor.shared.process(
                data,
                ratio: ratio,
                quarterTurns: quarterTurns,
                performance: performance
            )
            performance.record("libraryWriteStarted")
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: processedPhoto, options: nil)
            }
            performance.record("saved")
        case .live(let photoData, let movieURL):
            defer { try? FileManager.default.removeItem(at: movieURL) }
            let processed = try await livePhotoProcessor.process(
                photoData: photoData,
                movieURL: movieURL,
                ratio: ratio,
                quarterTurns: quarterTurns,
                performance: performance
            )
            defer {
                if processed.movieURL != movieURL {
                    try? FileManager.default.removeItem(at: processed.movieURL)
                }
            }
            performance.record("libraryWriteStarted")
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(
                    with: .photo,
                    data: processed.photoData,
                    options: nil
                )
                let movieOptions = PHAssetResourceCreationOptions()
                movieOptions.shouldMoveFile = true
                request.addResource(
                    with: .pairedVideo,
                    fileURL: processed.movieURL,
                    options: movieOptions
                )
            }
            performance.record("saved")
        }
    }
}
