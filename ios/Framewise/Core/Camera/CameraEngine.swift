//
//  CameraEngine.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation
import Foundation

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

    struct Capabilities {
        let zoomOptions: [ZoomOption]
        let zoomFactor: CGFloat
        let exposureRange: ClosedRange<Float>
        let flashModes: [AVCaptureDevice.FlashMode]
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.framewise.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var liveAudioInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var photoDelegate: PhotoDelegate?
    private var pinchStartZoomFactor: CGFloat?

    func start(completion: @escaping (Result<Capabilities, Error>) -> Void) {
        queue.async { [self] in
            do {
                if !isConfigured {
                    try configure()
                }
                if !session.isRunning {
                    session.startRunning()
                }
                guard session.isRunning, let device else {
                    throw CameraError.unavailable
                }
                let capabilities = Capabilities(
                    zoomOptions: zoomOptions(for: device),
                    zoomFactor: device.videoZoomFactor,
                    exposureRange: device
                        .minExposureTargetBias...device.maxExposureTargetBias,
                    flashModes: photoOutput.supportedFlashModes
                )
                DispatchQueue.main.async { completion(.success(capabilities)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if let device, device.isRampingVideoZoom {
                do {
                    try device.lockForConfiguration()
                    defer { device.unlockForConfiguration() }
                    device.videoZoomFactor = device.videoZoomFactor
                } catch {
                    print("Camera: could not stop zoom ramp: \(error)")
                }
            }
            pinchStartZoomFactor = nil
            if session.isRunning {
                session.stopRunning()
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
            let value = clampedZoomFactor(factor, for: device)
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
            guard let device else { return }
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

    private func clampedZoomFactor(
        _ factor: CGFloat,
        for device: AVCaptureDevice
    ) -> CGFloat {
        min(
            max(factor, device.minAvailableVideoZoomFactor),
            min(device.maxAvailableVideoZoomFactor, 10)
        )
    }

    func focusAndExpose(
        at point: CGPoint,
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
                let result: Result<Void, Error> =
                    changed
                    ? .success(()) : .failure(CameraError.unavailable)
                DispatchQueue.main.async { completion(result) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
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

    func enableLivePhoto(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async { [self] in
            do {
                guard isConfigured else { throw CameraError.unavailable }
                if photoOutput.isLivePhotoCaptureEnabled {
                    DispatchQueue.main.async { completion(.success(())) }
                    return
                }
                guard
                    AVCaptureDevice.authorizationStatus(for: .audio)
                        == .authorized,
                    let microphone = AVCaptureDevice.default(for: .audio)
                else {
                    throw CameraError.unavailable
                }
                let audioInput = try AVCaptureDeviceInput(device: microphone)
                guard session.canAddInput(audioInput) else {
                    throw CameraError.unavailable
                }

                let wasRunning = session.isRunning
                if wasRunning { session.stopRunning() }
                session.beginConfiguration()
                session.addInput(audioInput)
                session.commitConfiguration()
                guard photoOutput.isLivePhotoCaptureSupported else {
                    session.beginConfiguration()
                    session.removeInput(audioInput)
                    session.commitConfiguration()
                    if wasRunning { session.startRunning() }
                    throw CameraError.unavailable
                }
                photoOutput.isLivePhotoCaptureEnabled = true
                liveAudioInput = audioInput
                if wasRunning { session.startRunning() }
                guard !wasRunning || session.isRunning else {
                    throw CameraError.unavailable
                }
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func disableLivePhoto(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async { [self] in
            guard isConfigured else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.unavailable))
                }
                return
            }
            let wasRunning = session.isRunning
            if wasRunning { session.stopRunning() }
            photoOutput.isLivePhotoCaptureEnabled = false
            if let liveAudioInput {
                session.beginConfiguration()
                session.removeInput(liveAudioInput)
                session.commitConfiguration()
                self.liveAudioInput = nil
            }
            if wasRunning { session.startRunning() }
            let result: Result<Void, Error> =
                !wasRunning || session.isRunning
                ? .success(()) : .failure(CameraError.unavailable)
            DispatchQueue.main.async { completion(result) }
        }
    }

    func capture(
        livePhoto: Bool,
        flashMode: AVCaptureDevice.FlashMode,
        completion: @escaping (Result<CapturedPhoto, Error>) -> Void
    ) {
        queue.async { [self] in
            guard session.isRunning else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.unavailable))
                }
                return
            }
            guard
                !livePhoto
                    || (photoOutput.isLivePhotoCaptureEnabled
                        && !photoOutput.isLivePhotoCaptureSuspended)
            else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.unavailable))
                }
                return
            }
            guard photoOutput.supportedFlashModes.contains(flashMode) else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.unavailable))
                }
                return
            }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .balanced
            settings.flashMode = flashMode
            let movieURL =
                livePhoto
                ? FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "Framewise-\(UUID().uuidString).mov"
                    )
                : nil
            settings.livePhotoMovieFileURL = movieURL
            let delegate = PhotoDelegate(movieURL: movieURL) {
                [weak self] result in
                DispatchQueue.main.async {
                    completion(result)
                    self?.queue.async { self?.photoDelegate = nil }
                }
            }
            photoDelegate = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configure() throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        else {
            throw CameraError.permissionUnavailable
        }
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera,
            .builtInWideAngleCamera,
        ]
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        ).devices
        guard
            let device = deviceTypes.compactMap({ type in
                devices.first(where: { $0.deviceType == type })
            }).first
        else {
            throw CameraError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(photoOutput)
        else {
            throw CameraError.unavailable
        }
        if device.constituentDevices.first?.deviceType
            == AVCaptureDevice.DeviceType.builtInUltraWideCamera,
            let wideFactor = device.virtualDeviceSwitchOverVideoZoomFactors
                .first
        {
            try device.lockForConfiguration()
            device.videoZoomFactor = min(
                CGFloat(truncating: wideFactor),
                device.maxAvailableVideoZoomFactor
            )
            device.unlockForConfiguration()
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        session.addInput(input)
        session.addOutput(photoOutput)
        self.device = device
        isConfigured = true
    }

    private func zoomOptions(for device: AVCaptureDevice) -> [ZoomOption] {
        let switches = device.virtualDeviceSwitchOverVideoZoomFactors.map(
            \.doubleValue
        )
        let hasUltraWide =
            device.constituentDevices.first?.deviceType
            == AVCaptureDevice.DeviceType.builtInUltraWideCamera
        let oneX = hasUltraWide ? CGFloat(switches.first ?? 1) : 1
        var factors: [CGFloat] = [
            device.minAvailableVideoZoomFactor, oneX, oneX * 2,
        ]
        factors += switches.map { CGFloat($0) }
        let maximum = min(device.maxAvailableVideoZoomFactor, 10)
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
    fileprivate enum CameraError: Error {
        case unavailable
        case permissionUnavailable
    }

    fileprivate nonisolated final class PhotoDelegate: NSObject,
        AVCapturePhotoCaptureDelegate
    {
        private let completion: (Result<CapturedPhoto, Error>) -> Void
        private let movieURL: URL?
        private var photoData: Data?
        private var processedMovieURL: URL?
        private var processingError: Error?

        init(
            movieURL: URL?,
            completion: @escaping (Result<CapturedPhoto, Error>) -> Void
        ) {
            self.movieURL = movieURL
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
            } else {
                processingError = CameraError.unavailable
            }
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
