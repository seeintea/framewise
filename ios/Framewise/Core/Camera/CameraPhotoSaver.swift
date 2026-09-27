//
//  CameraPhotoSaver.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import Photos
import UIKit

extension Notification.Name {
    static let cameraPhotoSaveFailed = Notification.Name(
        "cameraPhotoSaveFailed"
    )
}

/// Owns processing and library writes after the capture delegate has released the shutter.
actor CameraPhotoSaver {
    static let shared = CameraPhotoSaver()

    private enum SaveError: Error { case invalidPhoto }
    private let livePhotoProcessor = LivePhotoProcessor()

    nonisolated func enqueue(
        _ captured: CameraEngine.CapturedPhoto,
        ratio: PhotoAspectRatio,
        quarterTurns: Int
    ) {
        Task.detached(priority: .utility) { [self] in
            do {
                try await save(
                    captured,
                    ratio: ratio,
                    quarterTurns: quarterTurns
                )
            } catch {
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
        quarterTurns: Int
    ) async throws {
        switch captured {
        case .still(let data):
            guard let image = ratio.renderedImage(
                from: data,
                quarterTurns: quarterTurns
            ) else {
                throw SaveError.invalidPhoto
            }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        case .live(let photoData, let movieURL):
            defer { try? FileManager.default.removeItem(at: movieURL) }
            let processed = try await livePhotoProcessor.process(
                photoData: photoData,
                movieURL: movieURL,
                ratio: ratio,
                quarterTurns: quarterTurns
            )
            defer {
                if processed.movieURL != movieURL {
                    try? FileManager.default.removeItem(at: processed.movieURL)
                }
            }
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(
                    with: .photo,
                    data: processed.photoData,
                    options: nil
                )
                request.addResource(
                    with: .pairedVideo,
                    fileURL: processed.movieURL,
                    options: nil
                )
            }
        }
    }
}
