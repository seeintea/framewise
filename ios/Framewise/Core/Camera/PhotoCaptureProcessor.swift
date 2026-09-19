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
    private let performanceCapture: CameraPerformance.Capture
    private let onWillCapture: @Sendable () -> Void
    private var sensorCaptureTimer: CameraPerformance.Timer?

    init(
        livePhotoMovieURL: URL?,
        performanceCapture: CameraPerformance.Capture,
        onWillCapture: @escaping @Sendable () -> Void,
        completion: @escaping Completion
    ) {
        requestedLivePhotoMovieURL = livePhotoMovieURL
        self.performanceCapture = performanceCapture
        self.onWillCapture = onWillCapture
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        CameraPerformance.record(
            "shutter_response",
            timer: performanceCapture.requestTimer,
            capture: performanceCapture
        )
        onWillCapture()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        CameraPerformance.record(
            "sensor_capture",
            timer: performanceCapture.requestTimer,
            capture: performanceCapture
        )
        sensorCaptureTimer = CameraPerformance.startTimer()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        recordPhotoProcessing(outcome: error == nil ? "success" : "failure")

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
            CameraPerformance.record(
                "live_movie_capture",
                timer: performanceCapture.requestTimer,
                capture: performanceCapture,
                outcome: "failure"
            )
            processingError = .captureFailed(error.localizedDescription)
            return
        }

        processedLivePhotoMovieURL = outputFileURL
        CameraPerformance.record(
            "live_movie_capture",
            timer: performanceCapture.requestTimer,
            capture: performanceCapture
        )
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        if let error {
            recordCaptureDelegateCompletion(outcome: "failure")
            finish(.failure(.captureFailed(error.localizedDescription)))
        } else if let processingError {
            recordCaptureDelegateCompletion(outcome: "failure")
            finish(.failure(processingError))
        } else if let photoData,
                  requestedLivePhotoMovieURL == nil {
            recordCaptureDelegateCompletion()
            finish(.success(.photo(photoData)))
        } else if let photoData,
                  let processedLivePhotoMovieURL {
            recordCaptureDelegateCompletion()
            finish(
                .success(
                    .livePhoto(
                        photoData: photoData,
                        pairedVideoURL: processedLivePhotoMovieURL
                    )
                )
            )
        } else {
            recordCaptureDelegateCompletion(outcome: "failure")
            finish(.failure(.photoDataUnavailable))
        }
    }

    private func recordPhotoProcessing(outcome: String = "success") {
        CameraPerformance.record(
            "system_photo_processing",
            timer: sensorCaptureTimer ?? performanceCapture.requestTimer,
            capture: performanceCapture,
            outcome: outcome
        )
    }

    private func recordCaptureDelegateCompletion(
        outcome: String = "success"
    ) {
        CameraPerformance.record(
            "capture_delegate_total",
            timer: performanceCapture.requestTimer,
            capture: performanceCapture,
            outcome: outcome
        )
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
