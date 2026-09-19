//
//  CameraCaptureService.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

@preconcurrency import AVFoundation

actor CameraCaptureService {
    nonisolated let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var photoProcessors: [Int64: PhotoCaptureProcessor] = [:]
    private var isConfigured = false

    func configure() throws -> CameraCapabilities {
        guard !isConfigured else {
            return currentCapabilities()
        }

        guard let device = Self.preferredBackCamera() else {
            throw CameraError.noCameraAvailable
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.cannotCreateInput(error.localizedDescription)
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            session.removeInput(input)
            session.commitConfiguration()
            throw CameraError.cannotAddPhotoOutput
        }
        session.addOutput(photoOutput)
        session.commitConfiguration()

        videoInput = input
        setDefaultZoomFactorIfPossible(on: device)
        isConfigured = true
        return currentCapabilities()
    }

    func start() throws {
        guard isConfigured else {
            throw CameraError.cannotStartSession
        }

        guard !session.isRunning else {
            return
        }

        session.startRunning()

        guard session.isRunning else {
            throw CameraError.cannotStartSession
        }
    }

    func stop() {
        guard session.isRunning else {
            return
        }

        session.stopRunning()
    }

    func setLivePhotoCaptureEnabled(_ isEnabled: Bool) throws -> Bool {
        guard isConfigured else {
            return false
        }

        let isAlreadyInRequestedState =
            photoOutput.isLivePhotoCaptureEnabled == isEnabled
            && (audioInput != nil) == isEnabled
        guard !isAlreadyInRequestedState else {
            return isEnabled
        }

        let wasRunning = session.isRunning
        if wasRunning {
            session.stopRunning()
        }

        session.beginConfiguration()

        if isEnabled {
            addAudioInputIfPossible()

            if audioInput != nil && photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = true
            } else {
                removeAudioInput()
                photoOutput.isLivePhotoCaptureEnabled = false
            }
        } else {
            photoOutput.isLivePhotoCaptureEnabled = false
            removeAudioInput()
        }

        session.commitConfiguration()

        if wasRunning {
            session.startRunning()
            guard session.isRunning else {
                throw CameraError.cannotStartSession
            }
        }

        return photoOutput.isLivePhotoCaptureEnabled
    }

    func switchCamera(
        preservingLivePhoto: Bool
    ) throws -> (CameraCapabilities, Bool) {
        guard let currentInput = videoInput else {
            throw CameraError.captureNotReady
        }

        let targetPosition: AVCaptureDevice.Position =
            currentInput.device.position == .back ? .front : .back
        guard let targetDevice = Self.preferredCamera(
            position: targetPosition
        ) else {
            return (
                currentCapabilities(),
                photoOutput.isLivePhotoCaptureEnabled
            )
        }

        let targetInput: AVCaptureDeviceInput
        do {
            targetInput = try AVCaptureDeviceInput(device: targetDevice)
        } catch {
            throw CameraError.cannotCreateInput(error.localizedDescription)
        }

        let wasRunning = session.isRunning
        if wasRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        photoOutput.isLivePhotoCaptureEnabled = false
        session.removeInput(currentInput)

        guard session.canAddInput(targetInput) else {
            if session.canAddInput(currentInput) {
                session.addInput(currentInput)
            }
            restoreLivePhotoIfPossible(preservingLivePhoto)
            session.commitConfiguration()
            try? restartSessionIfNeeded(wasRunning)
            throw CameraError.cannotAddInput
        }

        session.addInput(targetInput)
        videoInput = targetInput
        setDefaultZoomFactorIfPossible(on: targetDevice)
        restoreLivePhotoIfPossible(preservingLivePhoto)
        session.commitConfiguration()
        try restartSessionIfNeeded(wasRunning)

        return (
            currentCapabilities(),
            photoOutput.isLivePhotoCaptureEnabled
        )
    }

    func setZoomFactor(_ displayZoomFactor: Double) throws
        -> CameraCapabilities
    {
        guard let device = videoInput?.device else {
            throw CameraError.captureNotReady
        }

        let multiplier = max(device.displayVideoZoomFactorMultiplier, 0.01)
        let requestedFactor = CGFloat(displayZoomFactor) / multiplier
        let clampedFactor = min(
            max(requestedFactor, device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
        } catch {
            throw CameraError.runtimeError(error.localizedDescription)
        }

        return currentCapabilities()
    }

    func focusAndExpose(at devicePoint: CGPoint) throws -> CameraCapabilities {
        guard let device = videoInput?.device else {
            throw CameraError.captureNotReady
        }

        let point = CGPoint(
            x: min(max(devicePoint.x, 0), 1),
            y: min(max(devicePoint.y, 0), 1)
        )

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                } else if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }

            let neutralExposureBias = min(
                max(Float.zero, device.minExposureTargetBias),
                device.maxExposureTargetBias
            )
            device.setExposureTargetBias(
                neutralExposureBias,
                completionHandler: nil
            )
        } catch {
            throw CameraError.runtimeError(error.localizedDescription)
        }

        return currentCapabilities()
    }

    func setExposureBias(_ bias: Double) throws -> CameraCapabilities {
        guard let device = videoInput?.device else {
            throw CameraError.captureNotReady
        }

        let clampedBias = min(
            max(Float(bias), device.minExposureTargetBias),
            device.maxExposureTargetBias
        )

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.setExposureTargetBias(clampedBias, completionHandler: nil)
        } catch {
            throw CameraError.runtimeError(error.localizedDescription)
        }

        return currentCapabilities()
    }

    func capturePhoto(
        isLivePhotoEnabled: Bool,
        isFlashEnabled: Bool,
        rotationAngle: Double?,
        performanceCapture: CameraPerformance.Capture,
        onWillCapture: @escaping @Sendable () -> Void
    ) async throws -> CameraCaptureResult {
        guard isConfigured, session.isRunning else {
            throw CameraError.captureNotReady
        }

        configurePhotoConnection(rotationAngle: rotationAngle)

        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.hevc]
            )
        } else {
            settings = AVCapturePhotoSettings()
        }
        if isFlashEnabled,
           photoOutput.supportedFlashModes.contains(.on),
           videoInput?.device.hasFlash == true {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }

        let shouldCaptureLivePhoto =
            isLivePhotoEnabled
            && photoOutput.isLivePhotoCaptureEnabled
            && !photoOutput.isLivePhotoCaptureSuspended
        let livePhotoMovieURL = shouldCaptureLivePhoto
            ? Self.makeLivePhotoMovieURL()
            : nil
        settings.livePhotoMovieFileURL = livePhotoMovieURL

        let uniqueID = settings.uniqueID

        do {
            return try await withCheckedThrowingContinuation { continuation in
                let processor = PhotoCaptureProcessor(
                    livePhotoMovieURL: livePhotoMovieURL,
                    performanceCapture: performanceCapture,
                    onWillCapture: onWillCapture
                ) { [weak self] result in
                    continuation.resume(with: result)

                    Task {
                        await self?.finishCapture(uniqueID: uniqueID)
                    }
                }

                photoProcessors[uniqueID] = processor
                photoOutput.capturePhoto(with: settings, delegate: processor)
            }
        } catch {
            if let livePhotoMovieURL {
                try? FileManager.default.removeItem(at: livePhotoMovieURL)
            }
            throw error
        }
    }

    private func finishCapture(uniqueID: Int64) {
        photoProcessors[uniqueID] = nil
    }

    private func addAudioInputIfPossible() {
        guard audioInput == nil,
              let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }

        session.addInput(input)
        audioInput = input
    }

    private func removeAudioInput() {
        guard let audioInput else {
            return
        }

        session.removeInput(audioInput)
        self.audioInput = nil
    }

    private func restoreLivePhotoIfPossible(_ shouldEnable: Bool) {
        if shouldEnable && audioInput == nil {
            addAudioInputIfPossible()
        }

        let canEnable =
            shouldEnable
            && audioInput != nil
            && photoOutput.isLivePhotoCaptureSupported
        photoOutput.isLivePhotoCaptureEnabled = canEnable

        if !canEnable {
            removeAudioInput()
        }
    }

    private func configurePhotoConnection(rotationAngle: Double?) {
        guard let connection = photoOutput.connection(with: .video) else {
            return
        }

        if let rotationAngle {
            let angle = CGFloat(rotationAngle)
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = videoInput?.device.position == .front
        }
    }

    private func setDefaultZoomFactorIfPossible(on device: AVCaptureDevice) {
        let multiplier = max(device.displayVideoZoomFactorMultiplier, 0.01)
        let defaultFactor = min(
            max(1 / multiplier, device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = defaultFactor
            device.unlockForConfiguration()
        } catch {
            // Zoom remains at the device-provided value if configuration is busy.
        }
    }

    private func restartSessionIfNeeded(_ shouldRestart: Bool) throws {
        guard shouldRestart else {
            return
        }

        session.startRunning()
        guard session.isRunning else {
            throw CameraError.cannotStartSession
        }
    }

    private func currentCapabilities() -> CameraCapabilities {
        guard let device = videoInput?.device else {
            return .unavailable
        }

        let multiplier = max(device.displayVideoZoomFactorMultiplier, 0.01)
        let rawZoomFactors = [device.minAvailableVideoZoomFactor]
            + device.virtualDeviceSwitchOverVideoZoomFactors.map {
                CGFloat(truncating: $0)
            }
        let zoomFactors = rawZoomFactors
            .filter {
                $0 >= device.minAvailableVideoZoomFactor
                    && $0 <= device.maxAvailableVideoZoomFactor
            }
            .map { Self.roundedZoomFactor(Double($0 * multiplier)) }
            .reduce(into: [Double]()) { result, factor in
                guard !result.contains(where: { abs($0 - factor) < 0.01 }) else {
                    return
                }
                result.append(factor)
            }

        return CameraCapabilities(
            position: device.position == .front ? .front : .back,
            canSwitchCamera: Self.preferredCamera(
                position: device.position == .front ? .back : .front
            ) != nil,
            zoomFactors: zoomFactors,
            selectedZoomFactor: Self.roundedZoomFactor(
                Double(device.videoZoomFactor * multiplier)
            ),
            minimumZoomFactor: Double(
                device.minAvailableVideoZoomFactor * multiplier
            ),
            maximumZoomFactor: Double(
                device.maxAvailableVideoZoomFactor * multiplier
            ),
            isFlashAvailable: device.hasFlash
                && photoOutput.supportedFlashModes.contains(.on),
            isFocusPointAvailable:
                device.isFocusPointOfInterestSupported
                || device.isExposurePointOfInterestSupported,
            minimumExposureBias: Double(device.minExposureTargetBias),
            maximumExposureBias: Double(device.maxExposureTargetBias),
            selectedExposureBias: Double(device.exposureTargetBias)
        )
    }

    private static func makeLivePhotoMovieURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Framewise-\(UUID().uuidString)")
            .appendingPathExtension("mov")
    }

    private static func preferredBackCamera() -> AVCaptureDevice? {
        preferredCamera(position: .back)
    }

    private static func preferredCamera(
        position: AVCaptureDevice.Position
    ) -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType]
        if position == .back {
            preferredTypes = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
            ]
        } else {
            preferredTypes = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera,
            ]
        }

        for deviceType in preferredTypes {
            if let device = AVCaptureDevice.default(
                deviceType,
                for: .video,
                position: position
            ) {
                return device
            }
        }

        return nil
    }

    private static func roundedZoomFactor(_ factor: Double) -> Double {
        (factor * 10).rounded() / 10
    }
}
