//
//  CameraController.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation
import Combine

/// UI-free entry point for camera commands and the capture-to-save handoff.
/// AVFoundation guarantees readiness delegate callbacks on the main queue.
@MainActor
final class CameraController: NSObject,
    @preconcurrency AVCapturePhotoOutputReadinessCoordinatorDelegate
{
    enum SessionEvent {
        case interrupted(canResume: Bool)
        case recovering
        case recovered(CameraEngine.Capabilities)
        case failed
    }

    private let engine: CameraEngine
    private let readinessCoordinator: AVCapturePhotoOutputReadinessCoordinator
    private let orientation = CameraOrientationMonitor()
    private let saver = CameraPhotoSaver.shared
    private var lifecycleID = UUID()
    private var sessionOperationID = UUID()
    private var sessionObservers: Set<AnyCancellable> = []
    private var shouldRun = false
    private var hasStarted = false
    private var isRecovering = false
    private var canResumeInterruption = false
    private var isRunning = false
    private var prefersLivePhoto = false
    private var readinessPerformance: CameraSessionPerformance?
    private var capabilities: CameraEngine.Capabilities?
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
    var onSessionEvent: ((SessionEvent) -> Void)?

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
        if canCapture, let readinessPerformance {
            readinessPerformance.record("capture_ready")
            self.readinessPerformance = nil
        }
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
        let performance = CameraSessionPerformance(operation: .startup)
        let operationID = UUID()
        lifecycleID = operationID
        sessionOperationID = operationID
        shouldRun = true
        self.prefersLivePhoto = livePhotoEnabled
        hasStarted = false
        isRecovering = false
        canResumeInterruption = false
        isRunning = false
        readinessPerformance?.record("capture_ready", outcome: .cancelled)
        readinessPerformance = nil
        publishCaptureAvailability()
        observeSession(lifecycleID: operationID)
        orientation.start()
        engine.start(performance: performance) { [self] result in
            guard shouldRun, sessionOperationID == operationID else {
                performance.record("startup_total", outcome: .cancelled)
                return
            }
            if case .failure(CameraEngine.CameraError.interrupted) = result {
                performance.record("startup_total", outcome: .interrupted)
                handleInterruption(canResume: false)
                return
            }
            switch result {
            case .failure:
                performance.record("startup_total", outcome: .failure)
                completion(result)
            case .success:
                setLivePhotoEnabled(livePhotoEnabled, performance: performance) { result in
                    guard self.shouldRun, self.sessionOperationID == operationID else {
                        performance.record("startup_total", outcome: .cancelled)
                        return
                    }
                    switch result {
                    case .success(let capabilities):
                        performance.record(
                            "startup_total",
                            outcome: capabilities.livePhotoUnavailableReason == nil
                                ? .success : .fallback,
                            detail:
                                "camera=\(capabilities.isFrontCamera ? "front" : "back") live_requested=\(livePhotoEnabled) live_active=\(capabilities.isLivePhotoEnabled)"
                        )
                        self.readinessPerformance = performance
                        self.capabilities = capabilities
                        self.hasStarted = true
                        self.isRunning = true
                        self.publishCaptureAvailability()
                        completion(.success(capabilities))
                    case .failure(let error):
                        performance.record("startup_total", outcome: .failure)
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    func stop() {
        lifecycleID = UUID()
        sessionOperationID = UUID()
        sessionObservers.removeAll()
        readinessPerformance?.record("capture_ready", outcome: .cancelled)
        readinessPerformance = nil
        shouldRun = false
        hasStarted = false
        isRecovering = false
        isRunning = false
        publishCaptureAvailability()
        orientation.stop()
        engine.stop()
    }

    private func observeSession(lifecycleID: UUID) {
        sessionObservers.removeAll()
        NotificationCenter.default.publisher(
            for: AVCaptureSession.wasInterruptedNotification, object: session
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            let reason =
                (notification.userInfo?[AVCaptureSessionInterruptionReasonKey]
                as? NSNumber).flatMap {
                    AVCaptureSession.InterruptionReason(rawValue: $0.intValue)
                }
            let canResume =
                reason == .audioDeviceInUseByAnotherClient
                || reason == .videoDeviceInUseByAnotherClient
            Task { @MainActor [weak self] in
                guard let self, self.shouldRun, self.lifecycleID == lifecycleID else { return }
                self.handleInterruption(canResume: canResume)
            }
        }
        .store(in: &sessionObservers)

        NotificationCenter.default.publisher(
            for: AVCaptureSession.interruptionEndedNotification, object: session
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.shouldRun, self.lifecycleID == lifecycleID else { return }
                self.resumeSession()
            }
        }
        .store(in: &sessionObservers)

        NotificationCenter.default.publisher(
            for: AVCaptureSession.runtimeErrorNotification, object: session
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
            let wasReset = error?.code == .mediaServicesWereReset
            let description = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.shouldRun, self.lifecycleID == lifecycleID else { return }
                if let description { print("Camera session: \(description)") }
                if wasReset, self.hasStarted, !self.isRecovering {
                    self.isRunning = false
                    self.resumeSession()
                } else {
                    self.failSession()
                }
            }
        }
        .store(in: &sessionObservers)
    }

    private func handleInterruption(canResume: Bool) {
        sessionOperationID = UUID()
        isRecovering = false
        isRunning = false
        canResumeInterruption = canResume
        readinessPerformance?.record("capture_ready", outcome: .interrupted)
        readinessPerformance = nil
        publishCaptureAvailability()
        orientation.stopMonitoringFocusMovement()
        onSessionEvent?(.interrupted(canResume: canResume))
    }

    /// Reuse the configured inputs and Live Photo mode; do not rebuild the pipeline.
    func resumeSession() {
        guard shouldRun, !isRunning, !isRecovering else { return }
        let performance = CameraSessionPerformance(operation: .recovery)
        let operationID = UUID()
        sessionOperationID = operationID
        isRecovering = true
        isRunning = false
        publishCaptureAvailability()
        onSessionEvent?(.recovering)
        engine.start(restoringAutomaticFocus: true, performance: performance) {
            [weak self] result in
            guard let self, self.shouldRun, self.sessionOperationID == operationID else {
                performance.record("recovery_total", outcome: .cancelled)
                return
            }
            switch result {
            case .success:
                self.setLivePhotoEnabled(self.prefersLivePhoto, performance: performance) {
                    result in
                    guard self.shouldRun, self.sessionOperationID == operationID else {
                        performance.record("recovery_total", outcome: .cancelled)
                        return
                    }
                    self.isRecovering = false
                    switch result {
                    case .success(let capabilities):
                        performance.record(
                            "recovery_total",
                            outcome: capabilities.livePhotoUnavailableReason == nil
                                ? .success : .fallback,
                            detail:
                                "camera=\(capabilities.isFrontCamera ? "front" : "back") live_requested=\(self.prefersLivePhoto) live_active=\(capabilities.isLivePhotoEnabled)"
                        )
                        self.readinessPerformance = performance
                        self.capabilities = capabilities
                        self.hasStarted = true
                        self.isRunning = true
                        self.publishCaptureAvailability()
                        self.onSessionEvent?(.recovered(capabilities))
                    case .failure:
                        performance.record("recovery_total", outcome: .failure)
                        self.failSession()
                    }
                }
            case .failure(CameraEngine.CameraError.interrupted):
                performance.record("recovery_total", outcome: .interrupted)
                self.handleInterruption(canResume: self.canResumeInterruption)
            case .failure:
                performance.record("recovery_total", outcome: .failure)
                self.failSession()
            }
        }
    }

    private func failSession() {
        stop()
        onSessionEvent?(.failed)
    }

    func switchCamera(
        livePhotoEnabled: Bool,
        completion: @escaping (Result<CameraEngine.Capabilities, Error>) -> Void
    ) {
        let performance = CameraSessionPerformance(operation: .switchCamera)
        let operationID = sessionOperationID
        engine.switchCamera(livePhotoEnabled: livePhotoEnabled, performance: performance) {
            [self] result in
            guard shouldRun, sessionOperationID == operationID else {
                performance.record("switch_total", outcome: .cancelled)
                return
            }
            switch result {
            case .success(let capabilities):
                self.capabilities = capabilities
                self.prefersLivePhoto = livePhotoEnabled
                performance.record(
                    "switch_total",
                    outcome: capabilities.livePhotoUnavailableReason == nil ? .success : .fallback,
                    detail: capabilities.isLivePhotoEnabled ? "live" : "still")
            case .failure: performance.record("switch_total", outcome: .failure)
            }
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
        performance: CameraSessionPerformance = CameraSessionPerformance(operation: .livePhoto),
        completion: @escaping (Result<CameraEngine.Capabilities, Error>) -> Void
    ) {
        let operationID = sessionOperationID
        engine.setLivePhotoEnabled(enabled, performance: performance) { [weak self] result in
            guard let self, self.shouldRun, self.sessionOperationID == operationID else {
                performance.record("live_photo_result", outcome: .cancelled)
                completion(.failure(CancellationError()))
                return
            }
            switch result {
            case .success(let capabilities):
                self.prefersLivePhoto = enabled
                self.capabilities = capabilities
                performance.record(
                    "live_photo_result",
                    outcome: capabilities.livePhotoUnavailableReason == nil ? .success : .fallback)
            case .failure: performance.record("live_photo_result", outcome: .failure)
            }
            completion(result)
        }
    }

    func capture(
        ratio: PhotoAspectRatio,
        livePhoto: Bool,
        flashMode: AVCaptureDevice.FlashMode,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let performance = CameraCapturePerformance()
        let thumbnailCapture = CameraAlbumThumbnail.Capture()
        let quarterTurns = orientation.quarterTurns(for: ratio)
        let useHEIF = capabilities?.supportsHEIF == true
        #if DEBUG
            performance.record(
                "shutter ratio=\(ratio.rawValue) live=\(livePhoto) turns=\(quarterTurns) camera=\(capabilities?.isFrontCamera == true ? "front" : "back") codec=\(useHEIF ? "heif" : "jpeg")"
            )
        #endif
        let settings =
            useHEIF
            ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            : AVCapturePhotoSettings()
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
                    performance: performance,
                    thumbnailCapture: thumbnailCapture
                ) { [self] in
                    pendingPhotoCount -= 1
                    publishCaptureAvailability()
                }
                completion(.success(()))
            }
        }
    }
}
