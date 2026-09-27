//
//  CameraController.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation

/// UI-free entry point for camera commands and the capture-to-save handoff.
@MainActor
final class CameraController {
    private let engine = CameraEngine()
    private let orientation = CameraOrientationMonitor()
    private let saver = CameraPhotoSaver.shared
    private var lifecycleID = UUID()

    var session: AVCaptureSession { engine.session }
    var onOrientationChange: ((Int) -> Void)? {
        get { orientation.onHoldChange }
        set { orientation.onHoldChange = newValue }
    }

    func start(
        livePhotoEnabled: Bool,
        completion: @escaping (Result<CameraEngine.Capabilities, Error>) -> Void
    ) {
        let operationID = UUID()
        lifecycleID = operationID
        orientation.start()
        engine.start { [self] result in
            guard self.lifecycleID == operationID else { return }
            switch result {
            case .failure:
                completion(result)
            case .success(let capabilities):
                setLivePhotoEnabled(livePhotoEnabled) { result in
                    guard self.lifecycleID == operationID else { return }
                    switch result {
                    case .success: completion(.success(capabilities))
                    case .failure(let error): completion(.failure(error))
                    }
                }
            }
        }
    }

    func stop() {
        lifecycleID = UUID()
        orientation.stop()
        engine.stop()
    }

    func switchCamera(
        livePhotoEnabled: Bool,
        completion: @escaping (Result<CameraEngine.Capabilities, Error>) -> Void
    ) {
        let operationID = lifecycleID
        engine.switchCamera(livePhotoEnabled: livePhotoEnabled) { [self] result in
            guard lifecycleID == operationID else { return }
            completion(result)
        }
    }

    func setZoom(
        _ factor: CGFloat,
        animated: Bool,
        completion: @escaping (CGFloat) -> Void
    ) {
        engine.setZoom(factor, animated: animated, completion: completion)
    }

    func magnifyZoom(
        _ magnification: CGFloat,
        completion: @escaping (CGFloat) -> Void
    ) {
        engine.magnifyZoom(magnification, completion: completion)
    }

    func endZoomGesture() {
        engine.endZoomGesture()
    }

    func focusAndExpose(
        at point: CGPoint,
        onSceneChange: (() -> Void)? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let operationID = lifecycleID
        let handler = onSceneChange.map { onChange in
            { [weak self] in
                guard self?.lifecycleID == operationID else { return }
                onChange()
            }
        }
        if let handler {
            orientation.monitorFocusMovement(onChange: handler)
        } else {
            orientation.stopMonitoringFocusMovement()
        }
        engine.focusAndExpose(
            at: point,
            onSubjectAreaChange: handler,
            completion: completion
        )
    }

    func stopMonitoringFocusMovement() {
        orientation.stopMonitoringFocusMovement()
    }

    func setExposureBias(
        _ bias: Float,
        completion: @escaping (Result<Float, Error>) -> Void
    ) {
        engine.setExposureBias(bias, completion: completion)
    }

    func setLivePhotoEnabled(
        _ enabled: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if enabled {
            engine.enableLivePhoto(completion: completion)
        } else {
            engine.disableLivePhoto(completion: completion)
        }
    }

    func capture(
        ratio: PhotoAspectRatio,
        livePhoto: Bool,
        flashMode: AVCaptureDevice.FlashMode,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let timing = CameraCaptureTiming()
        let quarterTurns = orientation.quarterTurns(for: ratio)
        timing.record("shutter ratio=\(ratio.rawValue) live=\(livePhoto) turns=\(quarterTurns)")
        engine.capture(livePhoto: livePhoto, flashMode: flashMode, timing: timing) {
            [self] result in
            switch result {
            case .failure(let error):
                timing.record("captureFailed")
                completion(.failure(error))
            case .success(let captured):
                timing.record("captureDelivered")
                saver.enqueue(
                    captured,
                    ratio: ratio,
                    quarterTurns: quarterTurns,
                    timing: timing
                )
                completion(.success(()))
            }
        }
    }
}
