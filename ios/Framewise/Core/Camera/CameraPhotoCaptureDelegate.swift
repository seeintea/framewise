//
//  CameraPhotoCaptureDelegate.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import AVFoundation

/// Collects the resources and errors for one capture; the engine owns its lifetime.
nonisolated final class CameraPhotoCaptureDelegate: NSObject,
    AVCapturePhotoCaptureDelegate
{
    private let completion: (Result<CameraEngine.CapturedPhoto, Error>) -> Void
    private let movieURL: URL?
    private let performance: CameraCapturePerformance
    private var photoData: Data?
    private var processedMovieURL: URL?
    private var processingError: Error?

    init(
        movieURL: URL?,
        performance: CameraCapturePerformance,
        completion: @escaping (Result<CameraEngine.CapturedPhoto, Error>) -> Void
    ) {
        self.movieURL = movieURL
        self.performance = performance
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            processingError = error
        } else if let data = photo.fileDataRepresentation() {
            photoData = data
            #if DEBUG
                performance.record("photoReceived bytes=\(data.count)")
            #else
                performance.record("photoReceived")
            #endif
        } else {
            processingError = CameraEngine.CameraError.unavailable
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL,
        resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        // Recording is over, but the file is not usable until movieReceived.
        performance.record("movieRecordingFinished")
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            processingError = error
        } else {
            processedMovieURL = outputFileURL
            #if DEBUG
                performance.record(
                    "movieReceived duration=\(duration.seconds) photoTime=\(photoDisplayTime.seconds)"
                )
            #else
                performance.record("movieReceived")
            #endif
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings:
            AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        let result: Result<CameraEngine.CapturedPhoto, Error>
        if let error = error ?? processingError {
            result = .failure(error)
        } else if let photoData {
            if movieURL == nil {
                result = .success(.still(photoData))
            } else if let processedMovieURL {
                result = .success(
                    .live(photoData: photoData, movieURL: processedMovieURL)
                )
            } else {
                result = .failure(CameraEngine.CameraError.unavailable)
            }
        } else {
            result = .failure(CameraEngine.CameraError.unavailable)
        }
        if case .failure = result, let movieURL {
            try? FileManager.default.removeItem(at: movieURL)
        }
        completion(result)
    }
}
