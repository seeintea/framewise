//
//  CameraModel.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

@preconcurrency import AVFoundation
import Combine
import Foundation

enum CameraPageState: Equatable {
    case idle
    case requestingAuthorization
    case requestingMicrophoneAuthorization
    case configuring
    case ready
    case capturing
    case saving
    case interrupted
    case unavailable
    case failed(CameraError)
}

enum LivePhotoIssue: Equatable {
    case microphoneDenied
    case microphoneRestricted
    case unsupported

    var settingsCanResolve: Bool {
        switch self {
        case .microphoneDenied, .microphoneRestricted:
            true
        case .unsupported:
            false
        }
    }
}

@MainActor
final class CameraModel: ObservableObject {
    @Published private(set) var state = CameraPageState.idle
    @Published private(set) var showsSaveConfirmation = false
    @Published private(set) var isLivePhotoEnabled = false
    @Published private(set) var activeCaptureIsLivePhoto = false
    @Published private(set) var lastSavedCaptureWasLivePhoto = false
    @Published private(set) var livePhotoIssue: LivePhotoIssue?
    @Published private(set) var capabilities = CameraCapabilities.unavailable
    @Published private(set) var isFlashEnabled = false
    @Published private(set) var focusPoint: CGPoint?

    let session: AVCaptureSession

    private let captureService: CameraCaptureService
    private let livePhotoProcessor: LivePhotoProcessor
    private let photoLibraryWriter: PhotoLibraryWriter
    private var cancellables: Set<AnyCancellable> = []
    private var captureTask: Task<Void, Never>?
    private var zoomTask: Task<Void, Never>?
    private var confirmationTask: Task<Void, Never>?
    private var focusFeedbackTask: Task<Void, Never>?
    private var lifecycleGeneration = 0
    private var shouldRun = false
    private var prefersLivePhoto: Bool
    private var captureRotationAngle: Double?
    private var pendingZoomFactor: Double?

    init(
        captureService: CameraCaptureService = CameraCaptureService(),
        livePhotoProcessor: LivePhotoProcessor = LivePhotoProcessor(),
        photoLibraryWriter: PhotoLibraryWriter = PhotoLibraryWriter()
    ) {
        self.captureService = captureService
        self.livePhotoProcessor = livePhotoProcessor
        self.photoLibraryWriter = photoLibraryWriter
        prefersLivePhoto = UserDefaults.standard.object(
            forKey: AppSettingKey.isLivePhotoEnabled
        ) as? Bool ?? true
        session = captureService.session
        observeSession()
    }

    func start() async {
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        shouldRun = true

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            state = .requestingAuthorization
            let isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            guard isCurrent(generation) else {
                return
            }
            guard isAuthorized else {
                state = .failed(.authorizationDenied)
                return
            }
        case .denied:
            state = .failed(.authorizationDenied)
            return
        case .restricted:
            state = .failed(.authorizationRestricted)
            return
        @unknown default:
            state = .failed(.authorizationRestricted)
            return
        }

        guard isCurrent(generation) else {
            return
        }

        state = .configuring

        do {
            capabilities = try await captureService.configure()
            guard isCurrent(generation) else {
                return
            }

            try await prepareLivePhotoForStart(generation: generation)
            guard isCurrent(generation) else {
                return
            }

            try await captureService.start()
            guard isCurrent(generation) else {
                await captureService.stop()
                return
            }

            state = .ready
        } catch CameraError.noCameraAvailable {
            if isCurrent(generation) {
                state = .unavailable
            }
        } catch let error as CameraError {
            if isCurrent(generation) {
                state = .failed(error)
            }
        } catch {
            if isCurrent(generation) {
                state = .failed(.runtimeError(error.localizedDescription))
            }
        }
    }

    func stop() async {
        lifecycleGeneration += 1
        shouldRun = false
        focusFeedbackTask?.cancel()
        focusPoint = nil
        await captureService.stop()

        switch state {
        case .requestingAuthorization,
             .requestingMicrophoneAuthorization,
             .configuring,
             .ready,
             .capturing,
             .saving,
             .interrupted:
            state = .idle
        case .idle, .unavailable, .failed:
            break
        }
    }

    func retry() {
        Task {
            await start()
        }
    }

    func capturePhoto(outputAspectRatio: Double) {
        guard state == .ready, captureTask == nil else {
            return
        }

        let pendingZoomTask = zoomTask
        state = .capturing
        captureTask = Task { [weak self] in
            await pendingZoomTask?.value
            await self?.captureAndSavePhoto(
                outputAspectRatio: outputAspectRatio
            )
        }
    }

    func toggleFlash() {
        guard state == .ready,
              captureTask == nil,
              capabilities.isFlashAvailable else {
            return
        }

        isFlashEnabled.toggle()
    }

    func switchCamera() {
        guard state == .ready,
              capabilities.canSwitchCamera,
              captureTask == nil else {
            return
        }

        let generation = lifecycleGeneration
        let pendingZoomTask = zoomTask
        state = .configuring

        Task { [weak self] in
            await pendingZoomTask?.value
            await self?.performCameraSwitch(generation: generation)
        }
    }

    func selectZoomFactor(_ factor: Double) {
        guard state == .ready,
              captureTask == nil,
              capabilities.zoomFactors.contains(where: {
                  abs($0 - factor) < 0.01
              }) else {
            return
        }

        queueZoomFactor(factor)
    }

    func updateZoomFactor(_ factor: Double) {
        guard state == .ready, captureTask == nil else {
            return
        }

        let clampedFactor = min(
            max(factor, capabilities.minimumZoomFactor),
            capabilities.maximumZoomFactor
        )
        queueZoomFactor(clampedFactor)
    }

    func focus(previewPoint: CGPoint, devicePoint: CGPoint) {
        guard state == .ready,
              captureTask == nil,
              capabilities.isFocusPointAvailable else {
            return
        }

        focusFeedbackTask?.cancel()
        focusPoint = previewPoint
        let generation = lifecycleGeneration
        let pendingZoomTask = zoomTask

        Task { [weak self] in
            await pendingZoomTask?.value
            guard let self else {
                return
            }

            guard let newCapabilities = try? await self.captureService
                .focusAndExpose(at: devicePoint),
                  self.isCurrent(generation),
                  self.state == .ready,
                  self.captureTask == nil else {
                return
            }
            self.capabilities = newCapabilities
        }

        focusFeedbackTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            guard let self, self.isCurrent(generation) else {
                return
            }
            self.focusPoint = nil
        }
    }

    func selectExposureBias(_ bias: Double) {
        guard state == .ready,
              captureTask == nil,
              capabilities.isExposureBiasAvailable else {
            return
        }

        let generation = lifecycleGeneration
        Task { [weak self] in
            guard let self else {
                return
            }

            guard let newCapabilities = try? await self.captureService
                .setExposureBias(bias),
                  self.isCurrent(generation),
                  self.state == .ready else {
                return
            }
            self.capabilities = newCapabilities
        }
    }

    func updateCaptureRotationAngle(_ angle: Double) {
        captureRotationAngle = angle
    }

    func toggleLivePhoto() {
        guard state == .ready, captureTask == nil else {
            return
        }

        let shouldEnable = !isLivePhotoEnabled
        prefersLivePhoto = shouldEnable
        UserDefaults.standard.set(
            shouldEnable,
            forKey: AppSettingKey.isLivePhotoEnabled
        )

        let generation = lifecycleGeneration
        let pendingZoomTask = zoomTask
        state = .configuring
        Task { [weak self] in
            await pendingZoomTask?.value
            await self?.applyLivePhotoPreference(
                shouldEnable,
                generation: generation
            )
        }
    }

    func dismissLivePhotoIssue() {
        livePhotoIssue = nil
    }

    private func isCurrent(_ generation: Int) -> Bool {
        shouldRun && lifecycleGeneration == generation
    }

    private func captureAndSavePhoto(outputAspectRatio: Double) async {
        defer {
            captureTask = nil
            activeCaptureIsLivePhoto = false
        }

        do {
            activeCaptureIsLivePhoto = isLivePhotoEnabled
            let capturedResult = try await captureService.capturePhoto(
                isLivePhotoEnabled: activeCaptureIsLivePhoto,
                isFlashEnabled: isFlashEnabled,
                rotationAngle: captureRotationAngle
            )
            if state == .capturing {
                state = .saving
            }

            let result = try await livePhotoProcessor.process(
                capturedResult,
                targetAspectRatio: outputAspectRatio
            )
            try await photoLibraryWriter.save(result)

            guard state == .saving else {
                return
            }

            state = .ready
            lastSavedCaptureWasLivePhoto = result.isLivePhoto
            showSaveConfirmation()
        } catch let error as CameraError {
            if state == .capturing || state == .saving {
                state = .failed(error)
            }
        } catch {
            if state == .capturing || state == .saving {
                state = .failed(.captureFailed(error.localizedDescription))
            }
        }
    }

    private func prepareLivePhotoForStart(generation: Int) async throws {
        guard prefersLivePhoto else {
            _ = try await captureService.setLivePhotoCaptureEnabled(false)
            isLivePhotoEnabled = false
            livePhotoIssue = nil
            return
        }

        let authorizationStatus = await microphoneAuthorizationStatus()
        guard isCurrent(generation) else {
            return
        }

        state = .configuring

        switch authorizationStatus {
        case .authorized:
            let isEnabled = try await captureService
                .setLivePhotoCaptureEnabled(true)
            isLivePhotoEnabled = isEnabled
            livePhotoIssue = isEnabled ? nil : .unsupported
        case .denied:
            _ = try await captureService.setLivePhotoCaptureEnabled(false)
            isLivePhotoEnabled = false
            livePhotoIssue = .microphoneDenied
        case .restricted:
            _ = try await captureService.setLivePhotoCaptureEnabled(false)
            isLivePhotoEnabled = false
            livePhotoIssue = .microphoneRestricted
        case .notDetermined:
            _ = try await captureService.setLivePhotoCaptureEnabled(false)
            isLivePhotoEnabled = false
            livePhotoIssue = .microphoneDenied
        @unknown default:
            _ = try await captureService.setLivePhotoCaptureEnabled(false)
            isLivePhotoEnabled = false
            livePhotoIssue = .microphoneRestricted
        }
    }

    private func applyLivePhotoPreference(
        _ shouldEnable: Bool,
        generation: Int
    ) async {
        do {
            try await applyLivePhotoPreferenceValue(
                shouldEnable,
                generation: generation
            )
        } catch let error as CameraError {
            guard isCurrent(generation) else {
                return
            }
            state = .failed(error)
        } catch {
            guard isCurrent(generation) else {
                return
            }
            state = .failed(.runtimeError(error.localizedDescription))
        }
    }

    private func applyLivePhotoPreferenceValue(
        _ shouldEnable: Bool,
        generation: Int
    ) async throws {
        guard shouldEnable else {
            _ = try await captureService.setLivePhotoCaptureEnabled(false)
            guard isCurrent(generation) else {
                return
            }

            isLivePhotoEnabled = false
            livePhotoIssue = nil
            state = .ready
            return
        }

        let authorizationStatus = await microphoneAuthorizationStatus()
        guard isCurrent(generation) else {
            return
        }

        state = .configuring

        switch authorizationStatus {
        case .authorized:
            let isEnabled = try await captureService
                .setLivePhotoCaptureEnabled(true)
            guard isCurrent(generation) else {
                return
            }

            isLivePhotoEnabled = isEnabled
            livePhotoIssue = isEnabled ? nil : .unsupported
        case .denied:
            isLivePhotoEnabled = false
            livePhotoIssue = .microphoneDenied
        case .restricted:
            isLivePhotoEnabled = false
            livePhotoIssue = .microphoneRestricted
        case .notDetermined:
            isLivePhotoEnabled = false
            livePhotoIssue = .microphoneDenied
        @unknown default:
            isLivePhotoEnabled = false
            livePhotoIssue = .microphoneRestricted
        }

        state = .ready
    }

    private func microphoneAuthorizationStatus() async
        -> AVAuthorizationStatus
    {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        state = .requestingMicrophoneAuthorization
        let isAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
        return isAuthorized ? .authorized : .denied
    }

    private func showSaveConfirmation() {
        confirmationTask?.cancel()
        showsSaveConfirmation = true

        confirmationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1.5))
            } catch {
                return
            }

            self?.showsSaveConfirmation = false
        }
    }

    private func performCameraSwitch(generation: Int) async {
        do {
            let shouldAttemptLivePhoto = isLivePhotoEnabled
                || (prefersLivePhoto && livePhotoIssue == .unsupported)
            let (newCapabilities, isLivePhotoStillEnabled) =
                try await captureService.switchCamera(
                    preservingLivePhoto: shouldAttemptLivePhoto
                )
            guard isCurrent(generation) else {
                return
            }

            capabilities = newCapabilities
            isFlashEnabled = false
            focusFeedbackTask?.cancel()
            focusPoint = nil
            captureRotationAngle = nil
            isLivePhotoEnabled = isLivePhotoStillEnabled
            if prefersLivePhoto,
               !isLivePhotoStillEnabled,
               livePhotoIssue == nil || livePhotoIssue == .unsupported {
                livePhotoIssue = .unsupported
            } else if isLivePhotoStillEnabled {
                livePhotoIssue = nil
            }
            state = .ready
        } catch let error as CameraError {
            guard isCurrent(generation) else {
                return
            }
            state = .failed(error)
        } catch {
            guard isCurrent(generation) else {
                return
            }
            state = .failed(.runtimeError(error.localizedDescription))
        }
    }

    private func queueZoomFactor(_ factor: Double) {
        pendingZoomFactor = factor
        guard zoomTask == nil else {
            return
        }

        let generation = lifecycleGeneration
        zoomTask = Task { [weak self] in
            await self?.applyPendingZoomFactors(generation: generation)
        }
    }

    private func applyPendingZoomFactors(generation: Int) async {
        defer {
            zoomTask = nil
        }

        while let factor = pendingZoomFactor {
            pendingZoomFactor = nil

            do {
                let newCapabilities = try await captureService
                    .setZoomFactor(factor)
                guard isCurrent(generation),
                      state == .ready,
                      captureTask == nil else {
                    return
                }
                capabilities = newCapabilities
            } catch let error as CameraError {
                guard isCurrent(generation), state == .ready else {
                    return
                }
                state = .failed(error)
                return
            } catch {
                guard isCurrent(generation), state == .ready else {
                    return
                }
                state = .failed(.runtimeError(error.localizedDescription))
                return
            }
        }
    }

    private func observeSession() {
        NotificationCenter.default.publisher(
            for: AVCaptureSession.wasInterruptedNotification,
            object: session
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleInterruption()
            }
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: AVCaptureSession.interruptionEndedNotification,
            object: session
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleInterruptionEnded()
            }
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: AVCaptureSession.runtimeErrorNotification,
            object: session
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey]
                as? AVError
            let errorCode = error?.code
            let errorDescription = error?.localizedDescription

            Task { @MainActor [weak self] in
                await self?.handleRuntimeError(
                    code: errorCode,
                    description: errorDescription
                )
            }
        }
        .store(in: &cancellables)
    }

    private func handleInterruption() {
        guard shouldRun else {
            return
        }

        state = .interrupted
    }

    private func handleInterruptionEnded() async {
        guard shouldRun else {
            return
        }

        await start()
    }

    private func handleRuntimeError(
        code: AVError.Code?,
        description: String?
    ) async {
        guard shouldRun else {
            return
        }

        if code == .mediaServicesWereReset {
            await start()
            return
        }

        state = .failed(
            .runtimeError(description ?? "未知相机错误")
        )
        await captureService.stop()
    }
}
