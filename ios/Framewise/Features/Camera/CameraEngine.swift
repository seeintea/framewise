import AVFoundation
import Foundation

/// Owns all capture-device work on one serial queue. Permission requests stay in CameraAccess.
nonisolated final class CameraEngine: NSObject, @unchecked Sendable {
    struct ZoomOption: Equatable {
        let factor: CGFloat
        let label: String
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.framewise.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var photoDelegate: PhotoDelegate?

    func start(completion: @escaping (Result<[ZoomOption], Error>) -> Void) {
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
                let options = zoomOptions(for: device)
                DispatchQueue.main.async { completion(.success(options)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func setZoom(_ factor: CGFloat, completion: @escaping (CGFloat) -> Void) {
        queue.async { [self] in
            guard let device else { return }
            let value = min(max(factor, device.minAvailableVideoZoomFactor),
                            min(device.maxAvailableVideoZoomFactor, 10))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = value
                device.unlockForConfiguration()
                DispatchQueue.main.async { completion(value) }
            } catch {
                DispatchQueue.main.async { completion(device.videoZoomFactor) }
            }
        }
    }

    func capture(completion: @escaping (Result<Data, Error>) -> Void) {
        queue.async { [self] in
            guard session.isRunning else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.unavailable))
                }
                return
            }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .balanced
            let delegate = PhotoDelegate { [weak self] result in
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
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraError.permissionUnavailable
        }
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes, mediaType: .video, position: .back
        ).devices
        guard let device = deviceTypes.compactMap({ type in
            devices.first(where: { $0.deviceType == type })
        }).first else {
            throw CameraError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw CameraError.unavailable
        }
        if device.constituentDevices.first?.deviceType == AVCaptureDevice.DeviceType.builtInUltraWideCamera,
           let wideFactor = device.virtualDeviceSwitchOverVideoZoomFactors.first {
            try device.lockForConfiguration()
            device.videoZoomFactor = min(CGFloat(truncating: wideFactor),
                                         device.maxAvailableVideoZoomFactor)
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
        let switches = device.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)
        let hasUltraWide = device.constituentDevices.first?.deviceType == AVCaptureDevice.DeviceType.builtInUltraWideCamera
        let oneX = hasUltraWide ? CGFloat(switches.first ?? 1) : 1
        var factors: [CGFloat] = [device.minAvailableVideoZoomFactor, oneX, oneX * 2]
        factors += switches.map { CGFloat($0) }
        let maximum = min(device.maxAvailableVideoZoomFactor, 10)
        return factors
            .filter { $0 >= device.minAvailableVideoZoomFactor && $0 <= maximum }
            .sorted()
            .reduce(into: [CGFloat]()) { result, factor in
                if result.last.map({ abs($0 - factor) > 0.05 }) ?? true {
                    result.append(factor)
                }
            }
            .map { factor in
                let display = factor / oneX
                let label = display.rounded() == display
                    ? String(format: "%.0f×", Double(display))
                    : String(format: "%.1f×", Double(display))
                return ZoomOption(factor: factor, label: label)
            }
    }
}

private extension CameraEngine {
    enum CameraError: Error {
        case unavailable
        case permissionUnavailable
    }

    nonisolated final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        private let completion: (Result<Data, Error>) -> Void

        init(completion: @escaping (Result<Data, Error>) -> Void) {
            self.completion = completion
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            if let error {
                completion(.failure(error))
            } else if let data = photo.fileDataRepresentation() {
                completion(.success(data))
            } else {
                completion(.failure(CameraError.unavailable))
            }
        }
    }
}
