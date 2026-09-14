//
//  PhotoCaptureProcessor.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

@preconcurrency import AVFoundation

nonisolated final class PhotoCaptureProcessor: NSObject,
    AVCapturePhotoCaptureDelegate,
    @unchecked Sendable
{
    typealias Completion = @Sendable (
        Result<CameraCaptureResult, CameraError>
    ) -> Void

    private var completion: Completion?
    private let requestedLivePhotoMovieURL: URL?
    private var photoData: Data?
    private var processedLivePhotoMovieURL: URL?
    private var processingError: CameraError?

    init(
        livePhotoMovieURL: URL?,
        completion: @escaping Completion
    ) {
        requestedLivePhotoMovieURL = livePhotoMovieURL
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            processingError = .captureFailed(error.localizedDescription)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            processingError = .photoDataUnavailable
            return
        }

        photoData = data
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        if let error {
            processingError = .captureFailed(error.localizedDescription)
            return
        }

        processedLivePhotoMovieURL = outputFileURL
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        if let error {
            finish(.failure(.captureFailed(error.localizedDescription)))
        } else if let processingError {
            finish(.failure(processingError))
        } else if let photoData,
                  requestedLivePhotoMovieURL == nil {
            finish(.success(.photo(photoData)))
        } else if let photoData,
                  let processedLivePhotoMovieURL {
            finish(
                .success(
                    .livePhoto(
                        photoData: photoData,
                        pairedVideoURL: processedLivePhotoMovieURL
                    )
                )
            )
        } else {
            finish(.failure(.photoDataUnavailable))
        }
    }

    private func finish(
        _ result: Result<CameraCaptureResult, CameraError>
    ) {
        guard let completion else {
            return
        }

        self.completion = nil
        completion(result)
    }
}
