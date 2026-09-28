//
//  CameraEngine.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFAudio
import AVFoundation
import Foundation
import Synchronization

/// Owns all capture-device work on one serial queue. Permission requests stay in CameraAccess.
nonisolated final class CameraEngine: NSObject, @unchecked Sendable {
    enum CapturedPhoto: Sendable {
        case still(Data)
        case live(photoData: Data, movieURL: URL)
    }

    struct ZoomOption: Equatable {
        let factor: CGFloat
        let label: String
    }

    enum LivePhotoUnavailableReason: String, Sendable {
        case unsupported
        case microphoneDenied = "microphone_denied"
        case microphoneRestricted = "microphone_restricted"
        case microphoneUnavailable = "microphone_unavailable"
    }

    struct Capabilities {
        let isFrontCamera: Bool
        let canSwitchCamera: Bool
        let zoomOptions: [ZoomOption]
        let zoomFactor: CGFloat
        let exposureRange: ClosedRange<Float>
        let exposureBias: Float
        let flashModes: [AVCaptureDevice.FlashMode]
        let supportsHEIF: Bool
        let isLivePhotoEnabled: Bool
        let livePhotoUnavailableReason: LivePhotoUnavailableReason?
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.framewise.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var liveAudioInput: AVCaptureDeviceInput?
    private var livePhotoUnavailableReason: LivePhotoUnavailableReason?
    private var isConfigured = false
    private var photoDelegates: [Int64: PhotoDelegate] = [:]
    private var pinchStartZoomFactor: CGFloat?
    private var frontZoomFactor: CGFloat?
    private var subjectAreaObserver: NSObjectProtocol?
    private var subjectAreaMonitoringID = UUID()

    deinit {
        if let subjectAreaObserver {
            NotificationCenter.default.removeObserver(subjectAreaObserver)
        }
    }

    @MainActor
    func makeReadinessCoordinator() -> AVCapturePhotoOutputReadinessCoordinator {
        AVCapturePhotoOutputReadinessCoordinator(photoOutput: photoOutput)
    }

    func start(
        restoringAutomaticFocus: Bool = false,
        performance: CameraSessionPerformance,
        completion: @escaping (Result<Capabilities, Error>) -> Void
    ) {
        let queueStart = ContinuousClock.now
        queue.async { [self] in
            performance.record("session_queue_wait", since: queueStart)
            do {
                let permissionStart = ContinuousClock.now
                let isAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
                performance.record(
                    "camera_permission_check", since: permissionStart,
                    outcome: isAuthorized ? .success : .failure
                )
                guard isAuthorized
                else { throw CameraError.permissionUnavailable }
                let configurationStart = ContinuousClock.now
                if !isConfigured {
                    do {
                        try configure()
                        performance.record("session_configuration", since: configurationStart)
                    } catch {
                        performance.record(
                            "session_configuration", since: configurationStart, outcome: .failure)
                        throw error
                    }
                } else {
                    performance.record(
                        "session_configuration", since: configurationStart, outcome: .skipped)
                }
                let sessionStart = ContinuousClock.now
                let needsStart = !session.isRunning || session.isInterrupted
                if needsStart {
                    session.startRunning()
                }
                performance.record(
                    "session_start", since: sessionStart,
                    outcome: session.isInterrupted
                        ? .interrupted
                        : !session.isRunning ? .failure : needsStart ? .success : .skipped
                )
                guard !session.isInterrupted else { throw CameraError.interrupted }
                guard session.isRunning, let device else {
                    throw CameraError.unavailable
                }
                if restoringAutomaticFocus {
                    stopObservingSubjectAreaChanges()
                    try finishZoom(for: device)
                    try device.lockForConfiguration()
                    restoreAutomaticFocusAndExposure(on: device)
                    device.unlockForConfiguration()
                }
                let capabilities = capabilities(for: device)
                DispatchQueue.main.async { completion(.success(capabilities)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func stop() {
        let performance = CameraSessionPerformance(operation: .stop)
        let queueStart = ContinuousClock.now
        queue.async { [self] in
            performance.record("session_queue_wait", since: queueStart)
            stopObservingSubjectAreaChanges()
            if let device {
                do {
                    try finishZoom(for: device)
                } catch {
                    print("Camera: could not stop zoom ramp: \(error)")
                }
            }
            pinchStartZoomFactor = nil
            let stopStart = ContinuousClock.now
            let wasRunning = session.isRunning
            if wasRunning {
                session.stopRunning()
            }
            performance.record(
                "session_stop", since: stopStart, outcome: wasRunning ? .success : .skipped)
            performance.record("stop_total")
        }
    }

    func switchCamera(
        livePhotoEnabled: Bool,
        performance: CameraSessionPerformance,
        completion: @escaping (Result<Capabilities, Error>) -> Void
    ) {
        let queueStart = ContinuousClock.now
        queue.async { [self] in
            performance.record("session_queue_wait", since: queueStart)
            do {
                guard session.isRunning, photoDelegates.isEmpty,
                    let previousDevice = device, let previousInput = videoInput,
                    let nextDevice = captureDevice(
                        position: previousDevice.position == .front ? .back : .front
                    )
                else { throw CameraError.unavailable }
                let nextInput = try AVCaptureDeviceInput(device: nextDevice)
                try finishZoom(for: previousDevice)
                pinchStartZoomFactor = nil
                let wasLivePhotoEnabled = photoOutput.isLivePhotoCaptureEnabled
                let wasLivePhotoSuspended = photoOutput.isLivePhotoCaptureSuspended
                let previousAudioInput = liveAudioInput
                let previousLivePhotoIssue = livePhotoUnavailableReason

                let stopStart = ContinuousClock.now
                session.stopRunning()
                performance.record("session_stop", since: stopStart)
                let configurationStart = ContinuousClock.now
                session.beginConfiguration()
                session.removeInput(previousInput)
                guard session.canAddInput(nextInput) else {
                    performance.record(
                        "session_configuration", since: configurationStart, outcome: .failure)
                    session.addInput(previousInput)
                    session.commitConfiguration()
                    photoOutput.isLivePhotoCaptureEnabled = wasLivePhotoEnabled
                    if wasLivePhotoEnabled {
                        photoOutput.isLivePhotoCaptureSuspended = wasLivePhotoSuspended
                    }
                    configurePhotoMirroring(for: previousDevice)
                    prepareResponsiveCapture()
                    session.startRunning()
                    throw CameraError.unavailable
                }
                session.addInput(nextInput)
                session.commitConfiguration()
                performance.record("session_configuration", since: configurationStart)

                do {
                    prepareLivePhotoCapture(isActive: false)
                    try resetDevice(nextDevice)
                    try configureLivePhoto(livePhotoEnabled, performance: performance)
                    configurePhotoMirroring(for: nextDevice)
                    prepareResponsiveCapture()
                    let sessionStart = ContinuousClock.now
                    session.startRunning()
                    performance.record(
                        "session_start", since: sessionStart,
                        outcome: session.isRunning ? .success : .failure
                    )
                    guard session.isRunning else { throw CameraError.unavailable }
                } catch {
                    // Restore the working camera if any part of the replacement fails.
                    if session.isRunning { session.stopRunning() }
                    session.beginConfiguration()
                    session.removeInput(nextInput)
                    session.addInput(previousInput)
                    if liveAudioInput !== previousAudioInput {
                        if let liveAudioInput { session.removeInput(liveAudioInput) }
                        if let previousAudioInput { session.addInput(previousAudioInput) }
                        liveAudioInput = previousAudioInput
                    }
                    session.commitConfiguration()
                    livePhotoUnavailableReason = previousLivePhotoIssue
                    photoOutput.isLivePhotoCaptureEnabled = wasLivePhotoEnabled
                    if wasLivePhotoEnabled {
                        photoOutput.isLivePhotoCaptureSuspended = wasLivePhotoSuspended
                    }
                    configurePhotoMirroring(for: previousDevice)
                    prepareResponsiveCapture()
                    session.startRunning()
                    throw error
                }

                device = nextDevice
                stopObservingSubjectAreaChanges()
                videoInput = nextInput
                frontZoomFactor =
                    nextDevice.position == .front
                    ? nextDevice.videoZoomFactor : nil
                let capabilities = capabilities(for: nextDevice)
                DispatchQueue.main.async { completion(.success(capabilities)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func setZoom(
        _ factor: CGFloat,
        animated: Bool,
        completion: @escaping (CGFloat) -> Void
    ) {
        queue.async { [self] in
            guard let device else { return }
            let value: CGFloat
            if device.position == .front {
                // Front camera commands always resolve to one of the two framing presets.
                value =
                    zoomOptions(for: device).min {
                        abs($0.factor - factor) < abs($1.factor - factor)
                    }?.factor ?? device.minAvailableVideoZoomFactor
            } else {
                value = clampedZoomFactor(factor, for: device)
            }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                // Assigning the current factor immediately cancels a prior system ramp.
                if device.isRampingVideoZoom {
                    device.videoZoomFactor = device.videoZoomFactor
                }
                pinchStartZoomFactor = nil
                if animated && value != device.videoZoomFactor {
                    let distance = abs(log2(Double(value / device.videoZoomFactor)))
                    // Keep the verified system ramp's speed; acceleration is system-managed.
                    let nominalDuration = min(0.15 + max(distance - 1, 0) * 0.04, 0.20)
                    device.ramp(
                        toVideoZoomFactor: value,
                        withRate: Float(distance / nominalDuration)
                    )
                } else {
                    device.videoZoomFactor = value
                }
                if device.position == .front { frontZoomFactor = value }
                // Select the shortcut immediately while the device zoom animates.
                DispatchQueue.main.async { completion(value) }
            } catch {
                let currentFactor = device.videoZoomFactor
                DispatchQueue.main.async { completion(currentFactor) }
            }
        }
    }

    func magnifyZoom(
        _ magnification: CGFloat,
        completion: @escaping (CGFloat) -> Void
    ) {
        queue.async { [self] in
            guard let device, device.position == .back else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isRampingVideoZoom {
                    device.videoZoomFactor = device.videoZoomFactor
                }
                // A pinch takes over from the shortcut's current device zoom.
                let baseline = pinchStartZoomFactor ?? device.videoZoomFactor
                pinchStartZoomFactor = baseline
                let value = clampedZoomFactor(
                    baseline * magnification,
                    for: device
                )
                device.videoZoomFactor = value
                DispatchQueue.main.async { completion(value) }
            } catch {
                let currentFactor = device.videoZoomFactor
                DispatchQueue.main.async { completion(currentFactor) }
            }
        }
    }

    func endZoomGesture() {
        queue.async { [self] in pinchStartZoomFactor = nil }
    }

    private func finishZoom(for device: AVCaptureDevice) throws {
        guard device.isRampingVideoZoom else { return }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        // A front-camera ramp must never leave the device between framing presets.
        device.videoZoomFactor =
            device.position == .front
            ? frontZoomFactor ?? device.minAvailableVideoZoomFactor
            : device.videoZoomFactor
    }

    private func clampedZoomFactor(
        _ factor: CGFloat,
        for device: AVCaptureDevice
    ) -> CGFloat {
        min(
            max(factor, device.minAvailableVideoZoomFactor),
            maximumZoomFactor(for: device)
        )
    }

    private func maximumZoomFactor(for device: AVCaptureDevice) -> CGFloat {
        // The 25× limit is relative to the same 1× baseline used by the UI.
        min(device.maxAvailableVideoZoomFactor, oneXZoomFactor(for: device) * 25)
    }

    private func oneXZoomFactor(for device: AVCaptureDevice) -> CGFloat {
        guard
            device.constituentDevices.first?.deviceType
                == AVCaptureDevice.DeviceType.builtInUltraWideCamera,
            let wideFactor = device.virtualDeviceSwitchOverVideoZoomFactors.first
        else {
            return 1
        }
        return CGFloat(truncating: wideFactor)
    }

    func focusAndExpose(
        at point: CGPoint,
        onSubjectAreaChange: (() -> Void)? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async { [self] in
            guard let device else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.unavailable))
                }
                return
            }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                var changed = false
                if device.isFocusPointOfInterestSupported,
                    device.isFocusModeSupported(.continuousAutoFocus)
                {
                    device.focusPointOfInterest = point
                    device.focusMode = .continuousAutoFocus
                    changed = true
                }
                if device.isExposurePointOfInterestSupported,
                    device.isExposureModeSupported(.continuousAutoExposure)
                {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                    changed = true
                }
                if changed {
                    device.setExposureTargetBias(0, completionHandler: nil)
                    device.isSubjectAreaChangeMonitoringEnabled = onSubjectAreaChange != nil
                    stopObservingSubjectAreaChanges()
                    if let onSubjectAreaChange {
                        observeSubjectAreaChanges(for: device, onChange: onSubjectAreaChange)
                    }
                }
                let result: Result<Void, Error> =
                    changed
                    ? .success(()) : .failure(CameraError.unavailable)
                DispatchQueue.main.async { completion(result) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func observeSubjectAreaChanges(
        for observedDevice: AVCaptureDevice,
        onChange: @escaping () -> Void
    ) {
        let monitoringID = subjectAreaMonitoringID
        let deviceID = observedDevice.uniqueID
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.subjectAreaDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let eventDevice = notification.object as? AVCaptureDevice
            let eventDeviceID = eventDevice?.uniqueID
            self?.queue.async { [weak self] in
                guard let self else { return }
                guard self.subjectAreaMonitoringID == monitoringID,
                    self.device?.uniqueID == deviceID, eventDeviceID == deviceID,
                    self.session.isRunning
                else { return }
                DispatchQueue.main.async { onChange() }
            }
        }
    }

    private func stopObservingSubjectAreaChanges() {
        subjectAreaMonitoringID = UUID()
        if let subjectAreaObserver {
            NotificationCenter.default.removeObserver(subjectAreaObserver)
            self.subjectAreaObserver = nil
        }
    }

    func setExposureBias(
        _ bias: Float,
        completion: @escaping (Result<Float, Error>) -> Void
    ) {
        queue.async { [self] in
            guard let device else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.unavailable))
                }
                return
            }
            do {
                let value = min(
                    max(bias, device.minExposureTargetBias),
                    device.maxExposureTargetBias
                )
                try device.lockForConfiguration()
                device.setExposureTargetBias(value, completionHandler: nil)
                device.unlockForConfiguration()
                DispatchQueue.main.async { completion(.success(value)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func setLivePhotoEnabled(
        _ isEnabled: Bool,
        performance: CameraSessionPerformance,
        completion: @escaping (Result<Capabilities, Error>) -> Void
    ) {
        let queueStart = ContinuousClock.now
        queue.async { [self] in
            performance.record("live_photo_queue_wait", since: queueStart)
            do {
                try configureLivePhoto(isEnabled, performance: performance)
                guard let device else { throw CameraError.unavailable }
                let capabilities = capabilities(for: device)
                DispatchQueue.main.async { completion(.success(capabilities)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func configureLivePhoto(
        _ isEnabled: Bool, performance: CameraSessionPerformance
    ) throws {
        let start = ContinuousClock.now
        var outcome = CameraSessionPerformance.Outcome.success
        defer {
            performance.record(
                "live_photo_configuration", since: start, outcome: outcome,
                detail: livePhotoUnavailableReason?.rawValue ?? (isEnabled ? "enabled" : "disabled")
            )
        }
        do {
            guard isConfigured else { throw CameraError.unavailable }
            if !isEnabled {
                try disableLivePhoto()
                livePhotoUnavailableReason = nil
                return
            }
            let reason: LivePhotoUnavailableReason?
            if !photoOutput.isLivePhotoCaptureSupported {
                reason = .unsupported
            } else {
                switch AVCaptureDevice.authorizationStatus(for: .audio) {
                case .authorized: reason = try enableLivePhoto()
                case .denied: reason = .microphoneDenied
                case .restricted: reason = .microphoneRestricted
                case .notDetermined: reason = .microphoneUnavailable
                @unknown default: reason = .microphoneUnavailable
                }
            }
            if let reason {
                // Only unavailable Live capability falls back; configuration errors still fail.
                try disableLivePhoto()
                livePhotoUnavailableReason = reason
                outcome = .fallback
            } else {
                livePhotoUnavailableReason = nil
            }
        } catch {
            outcome = .failure
            throw error
        }
    }

    private func enableLivePhoto() throws -> LivePhotoUnavailableReason? {
        guard photoOutput.isLivePhotoCaptureEnabled else { throw CameraError.unavailable }
        // Recovery can reapply the already-active mode while a capture finishes.
        if liveAudioInput != nil, !photoOutput.isLivePhotoCaptureSuspended {
            allowHapticsWhileRecording()
            return nil
        }
        guard photoDelegates.isEmpty else { throw CameraError.unavailable }
        if liveAudioInput != nil {
            photoOutput.isLivePhotoCaptureSuspended = false
            allowHapticsWhileRecording()
            return nil
        }
        guard let microphone = AVCaptureDevice.default(for: .audio)
        else { return .microphoneUnavailable }
        let audioInput: AVCaptureDeviceInput
        do {
            audioInput = try AVCaptureDeviceInput(device: microphone)
        } catch {
            // A device input creation failure is an unavailable microphone, not a video failure.
            return .microphoneUnavailable
        }
        guard session.canAddInput(audioInput) else { return .microphoneUnavailable }
        let wasRunning = session.isRunning
        session.beginConfiguration()
        session.addInput(audioInput)
        session.commitConfiguration()
        guard photoOutput.isLivePhotoCaptureSupported,
            photoOutput.isLivePhotoCaptureEnabled,
            !wasRunning || session.isRunning
        else {
            session.beginConfiguration()
            session.removeInput(audioInput)
            session.commitConfiguration()
            if !photoOutput.isLivePhotoCaptureSupported { return .unsupported }
            throw CameraError.unavailable
        }
        photoOutput.isLivePhotoCaptureSuspended = false
        liveAudioInput = audioInput
        if let device { configurePhotoMirroring(for: device) }
        allowHapticsWhileRecording()
        return nil
    }

    private func disableLivePhoto() throws {
        if liveAudioInput == nil,
            !photoOutput.isLivePhotoCaptureEnabled || photoOutput.isLivePhotoCaptureSuspended
        {
            return
        }
        guard photoDelegates.isEmpty else { throw CameraError.unavailable }
        let wasRunning = session.isRunning
        if photoOutput.isLivePhotoCaptureEnabled {
            photoOutput.isLivePhotoCaptureSuspended = true
        }
        if let liveAudioInput {
            session.beginConfiguration()
            session.removeInput(liveAudioInput)
            session.commitConfiguration()
            self.liveAudioInput = nil
        }
        if let device { configurePhotoMirroring(for: device) }
        guard !wasRunning || session.isRunning else { throw CameraError.unavailable }
    }

    private func allowHapticsWhileRecording() {
        do {
            try AVAudioSession.sharedInstance()
                .setAllowHapticsAndSystemSoundsDuringRecording(true)
        } catch {
            // Haptic availability must not prevent an otherwise valid photo capture.
            print("Camera: could not allow haptics while recording: \(error)")
        }
    }

    func capture(
        settings: sending AVCapturePhotoSettings,
        performance: CameraCapturePerformance,
        completion: @escaping (Result<CapturedPhoto, Error>) -> Void
    ) {
        // Transfer the prepared, non-Sendable settings to the session queue safely.
        let request = Mutex(settings)
        queue.async { [self] in
            request.withLock { settings in
                submitCapture(settings: settings, performance: performance, completion: completion)
            }
        }
    }

    private func submitCapture(
        settings: AVCapturePhotoSettings,
        performance: CameraCapturePerformance,
        completion: @escaping (Result<CapturedPhoto, Error>) -> Void
    ) {
        guard session.isRunning, !session.isInterrupted else {
            DispatchQueue.main.async {
                completion(.failure(CameraError.unavailable))
            }
            return
        }
        guard
            settings.livePhotoMovieFileURL == nil
                || (photoOutput.isLivePhotoCaptureEnabled
                    && !photoOutput.isLivePhotoCaptureSuspended
                    && liveAudioInput != nil)
        else {
            DispatchQueue.main.async {
                completion(.failure(CameraError.unavailable))
            }
            return
        }
        guard photoOutput.supportedFlashModes.contains(settings.flashMode) else {
            DispatchQueue.main.async {
                completion(.failure(CameraError.unavailable))
            }
            return
        }
        if let device, device.position == .front {
            do {
                // Capture the selected framing even when its transition is still running.
                try finishZoom(for: device)
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
        }
        let requestID = settings.uniqueID
        let delegate = PhotoDelegate(
            movieURL: settings.livePhotoMovieFileURL,
            performance: performance
        ) {
            [weak self] result in
            self?.queue.async {
                self?.photoDelegates[requestID] = nil
                DispatchQueue.main.async { completion(result) }
            }
        }
        photoDelegates[requestID] = delegate
        performance.record("captureSubmitted")
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func configure() throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        else {
            throw CameraError.permissionUnavailable
        }
        guard let device = captureDevice(position: .back)
        else {
            throw CameraError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(photoOutput)
        else {
            throw CameraError.unavailable
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        session.addOutput(photoOutput)
        session.commitConfiguration()
        photoOutput.preservesLivePhotoCaptureSuspendedOnSessionStop = true
        prepareLivePhotoCapture(isActive: false)
        prepareResponsiveCapture()
        // Apply the initial framing after the session selects its capture format.
        do {
            try resetDevice(device)
        } catch {
            session.beginConfiguration()
            session.removeInput(input)
            session.removeOutput(photoOutput)
            session.commitConfiguration()
            throw error
        }
        configurePhotoMirroring(for: device)
        self.device = device
        videoInput = input
        isConfigured = true
    }

    /// Prepare the render pipeline while stopped; user toggles only suspend it.
    private func prepareLivePhotoCapture(isActive: Bool) {
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        if photoOutput.isLivePhotoCaptureEnabled {
            photoOutput.isLivePhotoCaptureSuspended = !isActive
        }
    }

    /// Configure while stopped because these options rebuild the capture pipeline.
    private func prepareResponsiveCapture() {
        if photoOutput.isZeroShutterLagSupported {
            photoOutput.isZeroShutterLagEnabled = true
        }
        if photoOutput.isResponsiveCaptureSupported {
            photoOutput.isResponsiveCaptureEnabled = true
        }
    }

    private func captureDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] =
            position == .front
            ? [.builtInUltraWideCamera, .builtInWideAngleCamera]
            : [
                .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera,
                .builtInWideAngleCamera,
            ]
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        ).devices
        return deviceTypes.compactMap { type in
            devices.first { $0.deviceType == type }
        }.first
    }

    private func resetDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.videoZoomFactor =
            device.position == .front
            ? device.minAvailableVideoZoomFactor
            : clampedZoomFactor(oneXZoomFactor(for: device), for: device)
        restoreAutomaticFocusAndExposure(on: device)
    }

    /// The caller holds the device configuration lock.
    private func restoreAutomaticFocusAndExposure(on device: AVCaptureDevice) {
        device.isSubjectAreaChangeMonitoringEnabled = false
        device.setExposureTargetBias(0, completionHandler: nil)
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
    }

    private func configurePhotoMirroring(for device: AVCaptureDevice) {
        guard let connection = photoOutput.connection(with: .video),
            connection.isVideoMirroringSupported
        else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = device.position == .front
    }

    private func capabilities(for device: AVCaptureDevice) -> Capabilities {
        Capabilities(
            isFrontCamera: device.position == .front,
            canSwitchCamera: captureDevice(
                position: device.position == .front ? .back : .front
            ) != nil,
            zoomOptions: zoomOptions(for: device),
            zoomFactor: frontZoomFactor ?? device.videoZoomFactor,
            exposureRange: device.minExposureTargetBias...device.maxExposureTargetBias,
            exposureBias: device.exposureTargetBias,
            flashModes: photoOutput.supportedFlashModes,
            supportsHEIF: photoOutput.availablePhotoCodecTypes.contains(.hevc),
            isLivePhotoEnabled: photoOutput.isLivePhotoCaptureEnabled
                && !photoOutput.isLivePhotoCaptureSuspended && liveAudioInput != nil,
            livePhotoUnavailableReason: livePhotoUnavailableReason
        )
    }

    private func zoomOptions(for device: AVCaptureDevice) -> [ZoomOption] {
        if device.position == .front {
            let wide = device.minAvailableVideoZoomFactor
            // A modest center crop for the narrow selfie preset; not the digital-zoom limit.
            // Verify the framing on hardware before claiming parity with Apple's Camera app.
            let narrow = min(wide * 1.3, device.maxAvailableVideoZoomFactor)
            var options = [
                ZoomOption(
                    factor: wide,
                    label: String(localized: "camera.zoom.front.wide")
                )
            ]
            if narrow > wide {
                options.append(
                    ZoomOption(
                        factor: narrow,
                        label: String(localized: "camera.zoom.front.narrow")
                    ))
            }
            return options
        }
        let switches = device.virtualDeviceSwitchOverVideoZoomFactors.map(
            \.doubleValue
        )
        let oneX = oneXZoomFactor(for: device)
        var factors: [CGFloat] = [
            device.minAvailableVideoZoomFactor, oneX, oneX * 2,
        ]
        factors += switches.map { CGFloat($0) }
        let maximum = maximumZoomFactor(for: device)
        return
            factors
            .filter {
                $0 >= device.minAvailableVideoZoomFactor && $0 <= maximum
            }
            .sorted()
            .reduce(into: [CGFloat]()) { result, factor in
                if result.last.map({ abs($0 - factor) > 0.05 }) ?? true {
                    result.append(factor)
                }
            }
            .map { factor in
                let display = factor / oneX
                let label =
                    display.rounded() == display
                    ? String(format: "%.0f×", Double(display))
                    : String(format: "%.1f×", Double(display))
                return ZoomOption(factor: factor, label: label)
            }
    }
}

extension CameraEngine {
    enum CameraError: Error {
        case unavailable
        case permissionUnavailable
        case interrupted
    }

    fileprivate nonisolated final class PhotoDelegate: NSObject,
        AVCapturePhotoCaptureDelegate
    {
        private let completion: (Result<CapturedPhoto, Error>) -> Void
        private let movieURL: URL?
        private let performance: CameraCapturePerformance
        private var photoData: Data?
        private var processedMovieURL: URL?
        private var processingError: Error?

        init(
            movieURL: URL?,
            performance: CameraCapturePerformance,
            completion: @escaping (Result<CapturedPhoto, Error>) -> Void
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
                processingError = CameraError.unavailable
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
            let result: Result<CapturedPhoto, Error>
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
                    result = .failure(CameraError.unavailable)
                }
            } else {
                result = .failure(CameraError.unavailable)
            }
            if case .failure = result, let movieURL {
                try? FileManager.default.removeItem(at: movieURL)
            }
            completion(result)
        }
    }
}
