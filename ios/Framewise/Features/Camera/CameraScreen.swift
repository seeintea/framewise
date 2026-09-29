import AVFoundation
import SwiftUI

struct CameraScreen: View {
    private enum CameraPhase: Equatable {
        case stopped
        case starting(UUID)
        case ready
        case switchingCamera(UUID)
        case changingLivePhoto(UUID)
        case capturing
        case interrupted(canResume: Bool)
        case recovering
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("camera.flashMode") private var storedFlashMode = 0
    @AppStorage("camera.annotationsVisible") private var areAnnotationsVisible =
        true

    let masks: [MaskContent]
    let initialMaskId: String
    let requestMicrophoneAccess: () async -> Bool
    @Binding var prefersLivePhoto: Bool

    @State private var camera = CameraController()
    @State private var albumThumbnail = CameraAlbumThumbnail.shared
    @State private var phase: CameraPhase = .stopped
    @State private var activeCaptureIDs: Set<UUID> = []
    @State private var isCaptureReady = false
    @State private var shutterFeedbackID = UUID()
    @State private var shutterFeedbackIsLivePhoto = false
    @State private var isShutterFeedbackVisible = false
    @State private var selectedMaskId: String
    @State private var captureRatio: PhotoAspectRatio
    @State private var zoomOptions: [CameraEngine.ZoomOption] = []
    @State private var zoomFactor: CGFloat = 1
    @GestureState private var selfieZoomTarget: CGFloat?
    @GestureState private var isZoomGestureActive = false
    @State private var isFrontCamera = false
    @State private var livePhotoEnabled = false
    @State private var livePhotoUnavailableReason: CameraEngine.LivePhotoUnavailableReason?
    @State private var canSwitchCamera = false
    @State private var cameraConfigurationID = UUID()
    @State private var exposureRange: ClosedRange<Float> = 0...0
    @State private var exposureBias: Double = 0
    @State private var flashModes: [AVCaptureDevice.FlashMode] = []
    @State private var focusPoint: CGPoint?
    @State private var focusSelectionID: UUID?
    @State private var pendingFocusResetID: UUID?
    @State private var isResettingFocus = false
    @State private var focusFeedbackTask: Task<Void, Never>?
    @State private var isFocusFeedbackDimmed = false
    @State private var exposureInteractionActive = false
    @State private var previewBottom: CGFloat?
    @State private var shutterTop: CGFloat?
    @State private var previewFrame = CGRect.zero
    @State private var zoomFrame = CGRect.zero
    @State private var showsMaskLoadError = false
    @State private var holdQuarterTurns = 0
    @State private var errorMessage: LocalizedStringResource?

    init(
        masks: [MaskContent],
        initialMaskId: String,
        requestMicrophoneAccess: @escaping () async -> Bool,
        prefersLivePhoto: Binding<Bool>
    ) {
        self.masks = masks
        self.initialMaskId = initialMaskId
        self.requestMicrophoneAccess = requestMicrophoneAccess
        self._prefersLivePhoto = prefersLivePhoto
        self._selectedMaskId = State(initialValue: initialMaskId)
        let initialMask = masks.first { $0.id == initialMaskId }
        self._captureRatio = State(
            initialValue: Self.photoRatio(
                for: initialMask?.defaultVariant.aspectRatio
            )
                ?? .standard
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight =
                geometry.size.height + geometry.safeAreaInsets.top
            let layout = CameraViewportLayout(
                aspectRatio: selectedMask?.defaultVariant.aspectRatio
                    ?? MaskAspectRatio(width: 3, height: 4),
                availableSize: CGSize(
                    width: geometry.size.width,
                    height: availableHeight
                ),
                landscapeRotation: holdQuarterTurns == 1
                    ? .degrees(-90) : .degrees(90)
            )

            preview(layout: layout)
                .frame(width: geometry.size.width, height: availableHeight)
                .offset(y: -geometry.safeAreaInsets.top)
        }
        .background(Color.black.ignoresSafeArea())
        .sensoryFeedback(
            .impact(weight: .light, intensity: 0.5),
            trigger: shutterFeedbackID
        )
        .overlay(alignment: .bottom) {
            CameraBottomControls(
                isAlbumEnabled: true,
                isCaptureEnabled: canCapture,
                canSwitchCamera: cameraControlsAppearReady && canSwitchCamera,
                onOpenAlbum: openAlbum,
                onCapture: capture,
                onSwitchCamera: switchCamera,
                controlRotation: controlRotation,
                maskOptions: masks.map {
                    CameraMaskOption(id: $0.id, title: $0.localization.title)
                },
                selectedMaskId: selectedMaskId,
                onSelectMask: selectMask,
                isCapturing: isCapturing,
                isCaptureFeedbackActive: isShutterFeedbackVisible,
                albumThumbnail: albumThumbnail.image
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value: controlRotation
            )
            .padding(.horizontal, 36)
            .padding(.bottom, masks.count >= 2 ? 0 : 16)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .named("cameraScreen")).minY
            } action: {
                shutterTop = $0
            }
        }
        .overlay {
            switch phase {
            case .interrupted(let canResume):
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                    Text(.cameraSessionInterruptedTitle)
                        .font(.headline)
                    Text(.cameraSessionInterruptedMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    if canResume {
                        Button(.cameraAccessActionRetry) { camera.resumeSession() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .foregroundStyle(.white)
                .padding(24)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
            case .recovering:
                ProgressView {
                    Text(.cameraSessionRecovering)
                }
                .tint(.white)
                .foregroundStyle(.white)
                .padding(24)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
            default:
                EmptyView()
            }
        }
        .overlay(alignment: .top) {
            if let reason = livePhotoUnavailableReason {
                HStack(spacing: 10) {
                    Image(systemName: "livephoto.slash")
                        .foregroundStyle(.yellow)
                    Text(livePhotoFallbackMessage(for: reason))
                        .font(.footnote)
                    Spacer(minLength: 4)
                    if reason == .microphoneDenied || reason == .microphoneRestricted {
                        Button(.cameraAccessActionOpenSettings) {
                            Task { await Permissions.openSettings() }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                    Button {
                        livePhotoUnavailableReason = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text(.cameraErrorOk))
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .overlay(alignment: .bottom) {
            if showsMaskLoadError {
                Text("模版加载失败")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                    .padding(.bottom, 160)
            }
        }
        .coordinateSpace(name: "cameraScreen")
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            CameraTopBarControls(
                flashMode: flashMode,
                availableFlashModes: flashModes,
                onToggleFlash: cycleFlashMode,
                isLivePhotoEnabled: livePhotoEnabled,
                onToggleLivePhoto: toggleLivePhoto,
                areAnnotationsVisible: areAnnotationsVisible,
                onToggleAnnotations: { areAnnotationsVisible.toggle() },
                onMore: {},
                controlRotation: controlRotation,
                isCameraReady: cameraControlsAppearReady,
                isCapturing: isCapturing,
                showsMore: false
            )
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            albumThumbnail.start()
            camera.onOrientationChange = { holdQuarterTurns = $0 }
            startCamera()
            guard masks.isEmpty else { return }
            showsMaskLoadError = true
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            showsMaskLoadError = false
        }
        .onDisappear {
            albumThumbnail.stop()
            stopCamera()
            camera.onOrientationChange = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                albumThumbnail.start()
                startCamera()
            } else {
                albumThumbnail.stop()
                stopCamera()
            }
        }
        .onChange(of: phase) { _, phase in
            if phase == .ready { resetFocusForSceneChangeIfNeeded() }
        }
        .alert(
            .cameraErrorTitle,
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(.cameraErrorOk, role: .cancel) { errorMessage = nil }
            if phase == .stopped {
                Button(.cameraAccessActionRetry) {
                    errorMessage = nil
                    startCamera()
                }
                if prefersLivePhoto {
                    Button(.cameraLiveDisable) {
                        prefersLivePhoto = false
                        errorMessage = nil
                        startCamera()
                    }
                }
            }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
    }

    private func preview(layout: CameraViewportLayout) -> some View {
        CameraPreview(session: camera.session, isMirrored: isFrontCamera) {
            devicePoint, viewPoint in
            focus(at: devicePoint, showAt: viewPoint)
        }
        .frame(
            width: layout.previewSize.width,
            height: layout.previewSize.height
        )
        .clipped()
        .gesture(
            MagnificationGesture()
                .updating($isZoomGestureActive) { _, active, _ in
                    guard phase == .ready else { return }
                    active = true
                }
                .updating($selfieZoomTarget) { value, target, _ in
                    guard phase == .ready, isFrontCamera, target == nil,
                        zoomOptions.count == 2
                    else { return }
                    // Front-camera pinches select a framing, never a continuous factor.
                    if value <= 0.9 {
                        target = zoomOptions.last?.factor
                    } else if value >= 1.1 {
                        target = zoomOptions.first?.factor
                    }
                }
                .onChanged { value in
                    guard phase == .ready, !isFrontCamera else { return }
                    let configurationID = cameraConfigurationID
                    camera.magnifyZoom(value) { value in
                        guard phase != .stopped, cameraConfigurationID == configurationID
                        else { return }
                        zoomFactor = value
                    }
                },
            including: phase == .ready ? .all : .subviews
        )
        .onChange(of: isZoomGestureActive) { _, isActive in
            if !isActive { camera.endZoomGesture() }
        }
        .onChange(of: selfieZoomTarget) { _, target in
            guard phase == .ready, isFrontCamera, let target,
                abs(target - zoomFactor) > 0.01
            else { return }
            setZoom(target)
        }
        .overlay {
            if let mask = selectedMask {
                CameraMaskOverlay(
                    variant: mask.defaultVariant,
                    annotationTextById: mask.annotationTextById(
                        variantId: mask.defaultVariant.id
                    ),
                    showsAnnotations: areAnnotationsVisible,
                    layout: layout
                )
                .allowsHitTesting(false)
            }

            if let focusPoint {
                CameraFocusExposureControl(
                    focusPoint: focusPoint,
                    minimumExposureBias: Double(exposureRange.lowerBound),
                    maximumExposureBias: Double(exposureRange.upperBound),
                    selectedExposureBias: exposureBias,
                    isExposureEnabled: phase == .ready && !isResettingFocus,
                    isExposureVisuallyEnabled: cameraControlsAppearReady && !isResettingFocus,
                    onSelectExposureBias: setExposureBias,
                    onExposureInteractionChanged: { active in
                        exposureInteractionActive = active
                        if active {
                            focusFeedbackTask?.cancel()
                            isFocusFeedbackDimmed = false
                        } else {
                            if pendingFocusResetID != nil {
                                resetFocusForSceneChangeIfNeeded()
                            } else {
                                scheduleFocusFeedbackTimeout()
                            }
                        }
                    },
                    controlRotation: controlRotation,
                    feedbackOpacity: isFocusFeedbackDimmed ? 0.5 : 1
                )
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.2),
                    value: controlRotation
                )
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named("cameraScreen"))
        } action: { frame in
            previewFrame = frame
            previewBottom = frame.maxY
        }
        .overlay(alignment: .bottom) {
            CameraZoomControls(
                zoomOptions: zoomOptions,
                selectedZoomFactor: zoomFactor,
                isEnabled: cameraControlsAppearReady,
                onSelectZoomFactor: setZoom,
                controlRotation: controlRotation,
                isFrontCamera: isFrontCamera
            )
            .allowsHitTesting(!isCapturing)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value: controlRotation
            )
            .padding(.bottom, 12)
            .offset(y: -zoomLift)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("cameraScreen"))
            } action: {
                zoomFrame = $0
            }
        }
        .frame(
            width: layout.previewSize.width,
            height: layout.previewSize.height
        )
        .overlay {
            if !reduceMotion, phase != .stopped {
                Color.black
                    .keyframeAnimator(initialValue: 0.0, trigger: shutterFeedbackID) {
                        content, opacity in
                        content.opacity(opacity)
                            .task(id: opacity > 0) { @MainActor in
                                isShutterFeedbackVisible = opacity > 0
                            }
                    } keyframes: { _ in
                        // Restart clear on each shot, including overlapping captures.
                        // Delay + darken + hold + reveal totals 450 ms / 760 ms.
                        MoveKeyframe(0.0)
                        LinearKeyframe(
                            0.0,
                            duration: shutterFeedbackIsLivePhoto ? 0.13 : 0.05
                        )
                        CubicKeyframe(
                            1.0,
                            duration: shutterFeedbackIsLivePhoto ? 0.16 : 0.08,
                            startVelocity: 0,
                            endVelocity: 0
                        )
                        LinearKeyframe(
                            1.0,
                            duration: shutterFeedbackIsLivePhoto ? 0.09 : 0.07
                        )
                        CubicKeyframe(
                            0.0,
                            duration: shutterFeedbackIsLivePhoto ? 0.38 : 0.25,
                            startVelocity: 0,
                            endVelocity: 0
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .onDisappear { isShutterFeedbackVisible = false }
            }
        }
    }

    private var isCapturing: Bool {
        phase == .capturing
    }

    private var canCapture: Bool {
        cameraControlsAppearReady && isCaptureReady && !zoomOptions.isEmpty
            && !isShutterFeedbackVisible
    }

    // Capture locks other camera controls without changing their normal appearance.
    // The command handlers below still require the actual ready phase.
    private var cameraControlsAppearReady: Bool {
        phase == .ready || isCapturing
    }

    private var selectedMask: MaskContent? {
        masks.first { $0.id == selectedMaskId }
    }

    private var controlRotation: Angle {
        // Capture quarter turns use the opposite sign from SwiftUI screen rotation.
        .degrees(Double(holdQuarterTurns * -90))
    }

    private var flashMode: AVCaptureDevice.FlashMode {
        let preferred =
            AVCaptureDevice.FlashMode(rawValue: storedFlashMode) ?? .off
        return flashModes.contains(preferred) ? preferred : .off
    }

    private func cycleFlashMode() {
        guard phase == .ready else { return }
        let order: [AVCaptureDevice.FlashMode] = [.off, .auto, .on]
        let supported = order.filter { flashModes.contains($0) }
        guard supported.count >= 2,
            let currentIndex = supported.firstIndex(of: flashMode)
        else { return }
        storedFlashMode =
            supported[(currentIndex + 1) % supported.count].rawValue
    }

    private var zoomLift: CGFloat {
        guard let previewBottom, let shutterTop else { return 0 }
        return max(0, previewBottom - 12 + 24 - shutterTop)
    }

    private func selectMask(_ id: String) {
        guard let mask = masks.first(where: { $0.id == id }),
            let ratio = Self.photoRatio(for: mask.defaultVariant.aspectRatio)
        else { return }
        selectedMaskId = id
        captureRatio = ratio
        focusPoint = nil
    }

    private static func photoRatio(for aspect: MaskAspectRatio?)
        -> PhotoAspectRatio?
    {
        guard let aspect else { return nil }
        switch (aspect.width, aspect.height) {
        case (1, 1): return .square
        case (3, 4): return .standard
        case (4, 3): return .standardLandscape
        case (9, 16): return .tall
        case (16, 9): return .tallLandscape
        default: return nil
        }
    }

    private func focus(at devicePoint: CGPoint, showAt viewPoint: CGPoint) {
        guard phase == .ready else { return }
        let screenPoint = CGPoint(
            x: previewFrame.minX + viewPoint.x,
            y: previewFrame.minY + viewPoint.y
        )
        guard !zoomFrame.contains(screenPoint) else { return }
        let selectionID = UUID()
        focusSelectionID = selectionID
        pendingFocusResetID = nil
        isResettingFocus = false
        isFocusFeedbackDimmed = false
        focusPoint = viewPoint
        scheduleFocusFeedbackTimeout()
        let configurationID = cameraConfigurationID
        camera.focusAndExpose(
            at: devicePoint,
            onSceneChange: {
                guard phase != .stopped, cameraConfigurationID == configurationID,
                    focusSelectionID == selectionID
                else { return }
                pendingFocusResetID = selectionID
                resetFocusForSceneChangeIfNeeded()
            }
        ) { result in
            guard phase != .stopped, cameraConfigurationID == configurationID,
                focusSelectionID == selectionID
            else { return }
            switch result {
            case .success:
                exposureBias = 0
            case .failure:
                clearPointFocus()
                errorMessage = .cameraErrorFocus
            }
        }
    }

    private func resetFocusForSceneChangeIfNeeded() {
        guard let selectionID = pendingFocusResetID, focusSelectionID == selectionID
        else { return }
        guard phase == .ready, !exposureInteractionActive, !isResettingFocus else { return }
        pendingFocusResetID = nil
        isResettingFocus = true
        focusFeedbackTask?.cancel()
        let configurationID = cameraConfigurationID
        camera.focusAndExpose(at: CGPoint(x: 0.5, y: 0.5)) { result in
            guard phase != .stopped, cameraConfigurationID == configurationID,
                focusSelectionID == selectionID
            else { return }
            isResettingFocus = false
            switch result {
            case .success:
                clearPointFocus()
                exposureBias = 0
            case .failure:
                scheduleFocusFeedbackTimeout()
                errorMessage = .cameraErrorFocus
            }
        }
    }

    private func clearPointFocus() {
        camera.stopMonitoringFocusMovement()
        focusSelectionID = nil
        pendingFocusResetID = nil
        isResettingFocus = false
        focusFeedbackTask?.cancel()
        focusPoint = nil
        isFocusFeedbackDimmed = false
        exposureInteractionActive = false
    }

    private func stopCamera() {
        phase = .stopped
        isShutterFeedbackVisible = false
        activeCaptureIDs.removeAll()
        isCaptureReady = false
        endPointFocus()
        camera.stop()
        camera.onCaptureAvailabilityChange = nil
        camera.onSessionEvent = nil
    }

    private func handleSessionEvent(_ event: CameraController.SessionEvent) {
        switch event {
        case .interrupted(let canResume):
            suspendCameraControls()
            phase = .interrupted(canResume: canResume)
        case .recovering:
            suspendCameraControls()
            phase = .recovering
        case .recovered(let capabilities):
            applyCapabilities(capabilities)
            phase = .ready
        case .failed:
            stopCamera()
            errorMessage = .cameraErrorRuntime
        }
    }

    private func suspendCameraControls() {
        cameraConfigurationID = UUID()
        activeCaptureIDs.removeAll()
        isCaptureReady = false
        isShutterFeedbackVisible = false
        clearPointFocus()
        camera.endZoomGesture()
    }

    private func endPointFocus() {
        if focusSelectionID != nil {
            camera.focusAndExpose(at: CGPoint(x: 0.5, y: 0.5)) { result in
                if case .failure(let error) = result {
                    print("Camera: could not restore automatic focus: \(error)")
                }
            }
        }
        clearPointFocus()
    }

    private func scheduleFocusFeedbackTimeout() {
        focusFeedbackTask?.cancel()
        focusFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled, !exposureInteractionActive,
                focusPoint != nil
            else { return }
            if exposureBias == 0 {
                focusPoint = nil
            } else {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    isFocusFeedbackDimmed = true
                }
            }
        }
    }

    private func startCamera() {
        guard phase == .stopped else { return }
        guard Permissions.check([.camera]).isAuthorized else {
            errorMessage = .cameraErrorPermission
            return
        }
        let operationID = UUID()
        cameraConfigurationID = operationID
        phase = .starting(operationID)
        camera.onCaptureAvailabilityChange = { isCaptureReady = $0 }
        camera.onSessionEvent = handleSessionEvent
        camera.start(livePhotoEnabled: prefersLivePhoto) { result in
            guard phase == .starting(operationID) else { return }
            switch result {
            case .success(let capabilities):
                applyCapabilities(capabilities)
                phase = .ready
            case .failure:
                stopCamera()
                errorMessage = .cameraErrorUnavailable
            }
        }
    }

    private func applyCapabilities(_ capabilities: CameraEngine.Capabilities) {
        isFrontCamera = capabilities.isFrontCamera
        canSwitchCamera = capabilities.canSwitchCamera
        zoomOptions = capabilities.zoomOptions
        zoomFactor = capabilities.zoomFactor
        exposureRange = capabilities.exposureRange
        exposureBias = Double(capabilities.exposureBias)
        flashModes = capabilities.flashModes
        livePhotoEnabled = capabilities.isLivePhotoEnabled
        livePhotoUnavailableReason = capabilities.livePhotoUnavailableReason
    }

    private func livePhotoFallbackMessage(
        for reason: CameraEngine.LivePhotoUnavailableReason
    ) -> LocalizedStringResource {
        switch reason {
        case .unsupported: .cameraLiveFallbackUnsupported
        case .microphoneDenied: .cameraLiveFallbackMicrophoneDenied
        case .microphoneRestricted: .cameraLiveFallbackMicrophoneRestricted
        case .microphoneUnavailable: .cameraLiveFallbackMicrophoneUnavailable
        }
    }

    private func switchCamera() {
        guard phase == .ready, canSwitchCamera else { return }
        let operationID = UUID()
        cameraConfigurationID = operationID
        phase = .switchingCamera(operationID)
        endPointFocus()
        camera.switchCamera(livePhotoEnabled: prefersLivePhoto) { result in
            guard phase == .switchingCamera(operationID) else { return }
            switch result {
            case .success(let capabilities):
                applyCapabilities(capabilities)
                phase = .ready
            case .failure:
                // Re-read the restored camera's actual settings before enabling controls.
                phase = .stopped
                startCamera()
                errorMessage = .cameraErrorSwitch
            }
        }
    }

    private func setZoom(_ requestedFactor: CGFloat) {
        guard phase == .ready else { return }
        let configurationID = cameraConfigurationID
        camera.setZoom(requestedFactor, animated: !reduceMotion) { value in
            guard phase != .stopped, cameraConfigurationID == configurationID
            else { return }
            zoomFactor = value
        }
    }

    private func setExposureBias(_ requestedBias: Double) {
        guard phase == .ready, !isResettingFocus else { return }
        let configurationID = cameraConfigurationID
        let selectionID = focusSelectionID
        exposureBias = requestedBias
        camera.setExposureBias(Float(requestedBias)) { result in
            guard phase != .stopped, cameraConfigurationID == configurationID,
                focusSelectionID == selectionID
            else { return }
            switch result {
            case .success(let value): exposureBias = Double(value)
            case .failure: errorMessage = .cameraErrorExposure
            }
        }
    }

    private func toggleLivePhoto() {
        guard phase == .ready else { return }
        let shouldEnable = !livePhotoEnabled
        let operationID = UUID()
        phase = .changingLivePhoto(operationID)
        if !shouldEnable {
            applyLivePhotoPreference(false, operationID: operationID)
            return
        }
        // Keep the user's intent if the system permission prompt pauses this page.
        prefersLivePhoto = true
        Task {
            _ = await requestMicrophoneAccess()
            guard phase == .changingLivePhoto(operationID) else { return }
            applyLivePhotoPreference(true, operationID: operationID)
        }
    }

    private func applyLivePhotoPreference(_ shouldEnable: Bool, operationID: UUID) {
        camera.setLivePhotoEnabled(shouldEnable) { result in
            guard phase == .changingLivePhoto(operationID) else { return }
            switch result {
            case .success(let capabilities):
                prefersLivePhoto = shouldEnable
                applyCapabilities(capabilities)
                phase = .ready
            case .failure:
                stopCamera()
                errorMessage = .cameraErrorLivePhoto
            }
        }
    }

    private func openAlbum() {
        // Photos has no documented launch URL. Treat this scheme as best effort;
        // opening it grants no PhotoKit access and cannot target an unsaved photo.
        guard let url = URL(string: "photos-redirect://") else { return }
        openURL(url) { accepted in
            if !accepted { errorMessage = .cameraAlbumOpenFailed }
        }
    }

    private func capture() {
        guard canCapture, camera.canCapture else { return }
        let ratioAtShutter = captureRatio
        let flashAtShutter = flashMode
        let livePhotoAtShutter = livePhotoEnabled
        let operationID = UUID()
        activeCaptureIDs.insert(operationID)
        phase = .capturing
        shutterFeedbackIsLivePhoto = livePhotoAtShutter
        shutterFeedbackID = operationID
        camera.capture(
            ratio: ratioAtShutter,
            livePhoto: livePhotoAtShutter,
            flashMode: flashAtShutter
        ) { result in
            guard activeCaptureIDs.remove(operationID) != nil else { return }
            if activeCaptureIDs.isEmpty, phase == .capturing { phase = .ready }
            if case .failure = result { errorMessage = .cameraErrorCapture }
        }
    }
}
