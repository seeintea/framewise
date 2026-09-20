//
//  CameraModel.swift
//  Framewise legacy camera snapshot
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

enum CameraConfigurationActivity: Equatable {
    case startup
    case livePhoto
    case switchingCamera
}

struct CameraTransientNotice: Equatable, Identifiable {
    enum Kind: Equatable {
        case livePhotoEnabled
        case livePhotoDisabled
    }

    let id = UUID()
    let kind: Kind
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
    @Published private(set) var configurationActivity:
        CameraConfigurationActivity?
    @Published private(set) var transientNotice: CameraTransientNotice?
    @Published private(set) var captureFeedbackTrigger = 0
    @Published private(set) var isLivePhotoEnabled = false
    @Published private(set) var livePhotoIssue: LivePhotoIssue?
    @Published private(set) var capabilities = CameraCapabilities.unavailable
    @Published private(set) var isFlashEnabled = false
    @Published private(set) var focusPoint: CGPoint?
    @Published private(set) var framingSnapshot: CameraFramingSnapshot?

    let session: AVCaptureSession

    private let captureService: CameraCaptureService
    private let livePhotoProcessor: LivePhotoProcessor
    private let photoLibraryWriter: PhotoLibraryWriter
    private var cancellables: Set<AnyCancellable> = []
    private var captureTask: Task<Void, Never>?
    private var zoomTask: Task<Void, Never>?
    private var transientNoticeTask: Task<Void, Never>?
    private var focusFeedbackTask: Task<Void, Never>?
    private var lifecycleGeneration = 0
    private var shouldRun = false
    private var prefersLivePhoto: Bool
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
        let startupTimer = CameraPerformance.startTimer()
        var startupOutcome = "cancelled"
        defer {
            CameraPerformance.record(
                "camera_ready",
                timer: startupTimer,
                outcome: startupOutcome
            )
        }

        let authorizationTimer = CameraPerformance.startTimer()
        let authorizationStatus = await cameraAuthorizationStatus()
        CameraPerformance.record(
            "camera_authorization",
            timer: authorizationTimer,
            detail: Self.authorizationDetail(authorizationStatus)
        )

        guard isCurrent(generation) else {
            return
        }

        switch authorizationStatus {
        case .authorized:
            break
        case .denied:
            startupOutcome = "failure"
            state = .failed(.authorizationDenied)
            return
        case .restricted:
            startupOutcome = "failure"
            state = .failed(.authorizationRestricted)
            return
        case .notDetermined:
            startupOutcome = "failure"
            state = .failed(.authorizationDenied)
            return
        @unknown default:
            startupOutcome = "failure"
            state = .failed(.authorizationRestricted)
            return
        }

        guard isCurrent(generation) else {
            return
        }

        configurationActivity = .startup
        state = .configuring

        do {
            let configurationTimer = CameraPerformance.startTimer()
            do {
                capabilities = try await captureService.configure()
                CameraPerformance.record(
                    "session_configuration",
                    timer: configurationTimer
                )
            } catch {
                CameraPerformance.record(
                    "session_configuration",
                    timer: configurationTimer,
                    outcome: "failure"
                )
                throw error
            }
            guard isCurrent(generation) else {
                return
            }

            let livePhotoTimer = CameraPerformance.startTimer()
            do {
                try await prepareLivePhotoForStart(generation: generation)
                CameraPerformance.record(
                    "live_photo_configuration",
                    timer: livePhotoTimer,
                    detail: isLivePhotoEnabled ? "enabled" : "disabled"
                )
            } catch {
                CameraPerformance.record(
                    "live_photo_configuration",
                    timer: livePhotoTimer,
                    outcome: "failure"
                )
                throw error
            }
            guard isCurrent(generation) else {
                return
            }

            let sessionStartTimer = CameraPerformance.startTimer()
            do {
                try await captureService.start()
                CameraPerformance.record(
                    "session_start",
                    timer: sessionStartTimer
                )
            } catch {
                CameraPerformance.record(
                    "session_start",
                    timer: sessionStartTimer,
                    outcome: "failure"
                )
                throw error
            }
            guard isCurrent(generation) else {
                await captureService.stop()
                return
            }

            configurationActivity = nil
            state = .ready
            startupOutcome = "success"
        } catch CameraError.noCameraAvailable {
            startupOutcome = "failure"
            if isCurrent(generation) {
                configurationActivity = nil
                state = .unavailable
            }
        } catch let error as CameraError {
            startupOutcome = "failure"
            if isCurrent(generation) {
                configurationActivity = nil
                state = .failed(error)
            }
        } catch {
            startupOutcome = "failure"
            if isCurrent(generation) {
                configurationActivity = nil
                state = .failed(.runtimeError(error.localizedDescription))
            }
        }
    }

    func stop() async {
        lifecycleGeneration += 1
        shouldRun = false
        focusFeedbackTask?.cancel()
        transientNoticeTask?.cancel()
        transientNotice = nil
        configurationActivity = nil
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

    func capturePhoto(
        previewAspectRatio: Double,
        outputAspectRatio: Double,
        templateToPreviewRotationAngle: Double
    ) {
        guard state == .ready,
              captureTask == nil,
              let framingSnapshot else {
            return
        }

        let outputPlan = CameraOutputPlan(
            framingSnapshot: framingSnapshot,
            previewAspectRatio: previewAspectRatio,
            targetAspectRatio: outputAspectRatio,
            captureToOutputRotationAngle:
                framingSnapshot.captureToPreviewRotationAngle
                - templateToPreviewRotationAngle
        )
        let pendingZoomTask = zoomTask
        let performanceCapture = CameraPerformance.startCapture(
            isLivePhoto: isLivePhotoEnabled
        )
        state = .capturing
        captureTask = Task { [weak self] in
            await pendingZoomTask?.value
            await self?.captureAndSavePhoto(
                outputPlan: outputPlan,
                performanceCapture: performanceCapture
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
        framingSnapshot = nil
        configurationActivity = .switchingCamera
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

        scheduleFocusFeedbackDismissal()
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

    func setExposureInteractionActive(_ isActive: Bool) {
        guard focusPoint != nil else {
            return
        }

        if isActive {
            focusFeedbackTask?.cancel()
        } else {
            scheduleFocusFeedbackDismissal()
        }
    }

    func updateFramingSnapshot(_ snapshot: CameraFramingSnapshot?) {
        framingSnapshot = snapshot
    }

    private func scheduleFocusFeedbackDismissal() {
        focusFeedbackTask?.cancel()
        let generation = lifecycleGeneration
        focusFeedbackTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }

            guard let self, self.isCurrent(generation) else {
                return
            }
            self.focusPoint = nil
        }
    }

    func toggleLivePhoto() {
        guard state == .ready, captureTask == nil else {
            return
        }

        transientNoticeTask?.cancel()
        transientNotice = nil
        let previousValue = isLivePhotoEnabled
        let shouldEnable = !isLivePhotoEnabled
        isLivePhotoEnabled = shouldEnable
        prefersLivePhoto = shouldEnable
        UserDefaults.standard.set(
            shouldEnable,
            forKey: AppSettingKey.isLivePhotoEnabled
        )

        let generation = lifecycleGeneration
        let pendingZoomTask = zoomTask
        configurationActivity = .livePhoto
        state = .configuring
        Task { [weak self] in
            await pendingZoomTask?.value
            await self?.applyLivePhotoPreference(
                shouldEnable,
                previousValue: previousValue,
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

    private func captureAndSavePhoto(
        outputPlan: CameraOutputPlan,
        performanceCapture: CameraPerformance.Capture
    ) async {
        var outcome = "success"
        defer {
            CameraPerformance.record(
                "capture_pipeline_total",
                timer: performanceCapture.requestTimer,
                capture: performanceCapture,
                outcome: outcome
            )
            captureTask = nil
        }

        do {
            let captured = try await captureService.capturePhoto(
                isLivePhotoEnabled: isLivePhotoEnabled,
                isFlashEnabled: isFlashEnabled,
                framingSnapshot: outputPlan.framingSnapshot,
                performanceCapture: performanceCapture,
                onWillCapture: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.captureFeedbackTrigger &+= 1
                    }
                }
            )
            if state == .capturing {
                state = .saving
            }

            let result = try await livePhotoProcessor.process(
                captured.result,
                outputPlan: outputPlan.resolvingPreviewRect(
                    captured.normalizedPreviewRect
                ),
                performanceCapture: performanceCapture
            )
            try await photoLibraryWriter.save(
                result,
                performanceCapture: performanceCapture
            )

            guard state == .saving else {
                return
            }

            state = .ready
        } catch let error as CameraError {
            outcome = "failure"
            if state == .capturing || state == .saving {
                state = .failed(error)
            }
        } catch {
            outcome = "failure"
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
        previousValue: Bool,
        generation: Int
    ) async {
        do {
            try await applyLivePhotoPreferenceValue(
                shouldEnable,
                generation: generation
            )
            guard isCurrent(generation) else {
                return
            }

            configurationActivity = nil
            state = .ready
            if shouldEnable, isLivePhotoEnabled {
                showTransientNotice(.livePhotoEnabled)
            } else if !shouldEnable {
                showTransientNotice(.livePhotoDisabled)
            }
        } catch let error as CameraError {
            guard isCurrent(generation) else {
                return
            }
            isLivePhotoEnabled = previousValue
            configurationActivity = nil
            state = .failed(error)
        } catch {
            guard isCurrent(generation) else {
                return
            }
            isLivePhotoEnabled = previousValue
            configurationActivity = nil
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

    }

    private func microphoneAuthorizationStatus() async
        -> AVAuthorizationStatus
    {
        let timer = CameraPerformance.startTimer()
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard currentStatus == .notDetermined else {
            CameraPerformance.record(
                "microphone_authorization",
                timer: timer,
                detail: Self.authorizationDetail(currentStatus)
            )
            return currentStatus
        }

        state = .requestingMicrophoneAuthorization
        let isAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
        let status: AVAuthorizationStatus = isAuthorized ? .authorized : .denied
        CameraPerformance.record(
            "microphone_authorization",
            timer: timer,
            detail: Self.authorizationDetail(status)
        )
        return status
    }

    private func cameraAuthorizationStatus() async -> AVAuthorizationStatus {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        state = .requestingAuthorization
        let isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        return isAuthorized ? .authorized : .denied
    }

    private static func authorizationDetail(
        _ status: AVAuthorizationStatus
    ) -> String {
        switch status {
        case .notDetermined:
            "not_determined"
        case .restricted:
            "restricted"
        case .denied:
            "denied"
        case .authorized:
            "authorized"
        @unknown default:
            "unknown"
        }
    }

    private func showTransientNotice(
        _ kind: CameraTransientNotice.Kind
    ) {
        transientNoticeTask?.cancel()
        let notice = CameraTransientNotice(kind: kind)
        transientNotice = notice

        transientNoticeTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            guard self?.transientNotice?.id == notice.id else {
                return
            }
            self?.transientNotice = nil
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
            isLivePhotoEnabled = isLivePhotoStillEnabled
            if prefersLivePhoto,
               !isLivePhotoStillEnabled,
               livePhotoIssue == nil || livePhotoIssue == .unsupported {
                livePhotoIssue = .unsupported
            } else if isLivePhotoStillEnabled {
                livePhotoIssue = nil
            }
            configurationActivity = nil
            state = .ready
        } catch let error as CameraError {
            guard isCurrent(generation) else {
                return
            }
            configurationActivity = nil
            state = .failed(error)
        } catch {
            guard isCurrent(generation) else {
                return
            }
            configurationActivity = nil
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

        configurationActivity = nil
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

        configurationActivity = nil
        state = .failed(
            .runtimeError(description ?? "未知相机错误")
        )
        await captureService.stop()
    }
}
