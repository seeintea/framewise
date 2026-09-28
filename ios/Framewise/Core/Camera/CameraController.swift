//
//  CameraController.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation

/// UI-free entry point for camera commands and the capture-to-save handoff.
/// AVFoundation guarantees readiness delegate callbacks on the main queue.
@MainActor
final class CameraController: NSObject,
    @preconcurrency AVCapturePhotoOutputReadinessCoordinatorDelegate
{
    private let engine: CameraEngine
    private let readinessCoordinator: AVCapturePhotoOutputReadinessCoordinator
    private let orientation = CameraOrientationMonitor()
    private let saver = CameraPhotoSaver.shared
    private var lifecycleID = UUID()
    private var isRunning = false
    private var pendingPhotoCount = 0
    // Include downstream processing and library writes in the trial's memory bound.
    private let maximumPendingPhotos = 3

    var canCapture: Bool {
        isRunning && readinessCoordinator.captureReadiness == .ready
            && pendingPhotoCount < maximumPendingPhotos
    }

    var onCaptureAvailabilityChange: ((Bool) -> Void)? {
        didSet { publishCaptureAvailability() }
    }

    override init() {
        let engine = CameraEngine()
        self.engine = engine
        readinessCoordinator = engine.makeReadinessCoordinator()
        super.init()
        readinessCoordinator.delegate = self
    }

    func readinessCoordinator(
        _ coordinator: AVCapturePhotoOutputReadinessCoordinator,
        captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness
    ) {
        publishCaptureAvailability()
    }

    private func publishCaptureAvailability() {
        onCaptureAvailabilityChange?(canCapture)
    }

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
                    case .success:
                        self.isRunning = true
                        self.publishCaptureAvailability()
                        completion(.success(capabilities))
                    case .failure(let error): completion(.failure(error))
                    }
                }
            }
        }
    }

    func stop() {
        lifecycleID = UUID()
        isRunning = false
        publishCaptureAvailability()
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
        let performance = CameraCapturePerformance()
        let quarterTurns = orientation.quarterTurns(for: ratio)
        performance.record("shutter ratio=\(ratio.rawValue) live=\(livePhoto) turns=\(quarterTurns)")
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced
        settings.flashMode = flashMode
        if livePhoto {
            settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Framewise-\(UUID().uuidString).mov")
        }
        pendingPhotoCount += 1
        readinessCoordinator.startTrackingCaptureRequest(using: settings)
        publishCaptureAvailability()
        let requestID = settings.uniqueID
        engine.capture(settings: settings, performance: performance) {
            [self] result in
            switch result {
            case .failure(let error):
                readinessCoordinator.stopTrackingCaptureRequest(using: requestID)
                pendingPhotoCount -= 1
                publishCaptureAvailability()
                performance.record("captureFailed")
                completion(.failure(error))
            case .success(let captured):
                performance.record("captureDelivered")
                saver.enqueue(
                    captured,
                    ratio: ratio,
                    quarterTurns: quarterTurns,
                    performance: performance
                ) { [self] in
                    pendingPhotoCount -= 1
                    publishCaptureAvailability()
                }
                completion(.success(()))
            }
        }
    }
}
