import AVFoundation
import SwiftUI

struct CameraScreen: View {
    private enum CameraPhase: Equatable {
        case stopped
        case starting(UUID)
        case ready
        case changingLivePhoto(UUID)
        case capturing(UUID)
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("camera.flashMode") private var storedFlashMode = 0
    @AppStorage("camera.annotationsVisible") private var areAnnotationsVisible =
        true

    let masks: [MaskContent]
    let initialMaskId: String
    let requestMicrophoneAccess: () async -> Bool
    @Binding var livePhotoEnabled: Bool

    @State private var camera = CameraController()
    @State private var phase: CameraPhase = .stopped
    @State private var selectedMaskId: String
    @State private var captureRatio: PhotoAspectRatio
    @State private var zoomOptions: [CameraEngine.ZoomOption] = []
    @State private var zoomFactor: CGFloat = 1
    @State private var exposureRange: ClosedRange<Float> = 0...0
    @State private var exposureBias: Double = 0
    @State private var flashModes: [AVCaptureDevice.FlashMode] = []
    @State private var focusPoint: CGPoint?
    @State private var focusFeedbackTask: Task<Void, Never>?
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
        livePhotoEnabled: Binding<Bool>
    ) {
        self.masks = masks
        self.initialMaskId = initialMaskId
        self.requestMicrophoneAccess = requestMicrophoneAccess
        self._livePhotoEnabled = livePhotoEnabled
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
        .overlay(alignment: .bottom) {
            CameraBottomControls(
                isAlbumEnabled: false,
                isCaptureEnabled: phase == .ready && !zoomOptions.isEmpty,
                canSwitchCamera: false,
                onOpenAlbum: {},
                onCapture: capture,
                onSwitchCamera: {},
                controlRotation: controlRotation,
                maskOptions: masks.map {
                    CameraMaskOption(id: $0.id, title: $0.localization.title)
                },
                selectedMaskId: selectedMaskId,
                onSelectMask: selectMask
            )
            .padding(.horizontal, 36)
            .padding(.bottom, masks.count >= 2 ? 0 : 16)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .named("cameraScreen")).minY
            } action: {
                shutterTop = $0
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
                isCameraReady: phase == .ready,
                showsMore: false
            )
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            camera.onOrientationChange = { holdQuarterTurns = $0 }
            startCamera()
            guard masks.isEmpty else { return }
            showsMaskLoadError = true
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            showsMaskLoadError = false
        }
        .onDisappear {
            phase = .stopped
            camera.stop()
            camera.onOrientationChange = nil
            focusFeedbackTask?.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                startCamera()
            } else {
                self.phase = .stopped
                camera.stop()
            }
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
                if livePhotoEnabled {
                    Button(.cameraLiveDisable) {
                        livePhotoEnabled = false
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
        CameraPreview(session: camera.session) { devicePoint, viewPoint in
            focus(at: devicePoint, showAt: viewPoint)
        }
        .frame(
            width: layout.previewSize.width,
            height: layout.previewSize.height
        )
        .clipped()
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    camera.magnifyZoom(value) { zoomFactor = $0 }
                }
                .onEnded { _ in camera.endZoomGesture() }
        )
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
                    isExposureEnabled: phase == .ready,
                    onSelectExposureBias: setExposureBias,
                    onExposureInteractionChanged: { active in
                        exposureInteractionActive = active
                        if active {
                            focusFeedbackTask?.cancel()
                        } else {
                            scheduleFocusDismissal()
                        }
                    },
                    controlRotation: controlRotation
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
                isEnabled: phase == .ready,
                onSelectZoomFactor: setZoom,
                controlRotation: controlRotation
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
    }

    private var selectedMask: MaskContent? {
        masks.first { $0.id == selectedMaskId }
    }

    private var controlRotation: Angle {
        .degrees(Double(holdQuarterTurns * 90))
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
        focusPoint = viewPoint
        scheduleFocusDismissal()
        camera.focusAndExpose(at: devicePoint) { result in
            if case .failure = result {
                focusPoint = nil
                errorMessage = .cameraErrorFocus
            }
        }
    }

    private func scheduleFocusDismissal() {
        focusFeedbackTask?.cancel()
        focusFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled, !exposureInteractionActive else { return }
            focusPoint = nil
        }
    }

    private func startCamera() {
        guard phase == .stopped else { return }
        guard Permissions.check([.camera]).isAuthorized else {
            errorMessage = .cameraErrorPermission
            return
        }
        let operationID = UUID()
        phase = .starting(operationID)
        camera.start(livePhotoEnabled: livePhotoEnabled) { result in
            guard phase == .starting(operationID) else { return }
            switch result {
            case .success(let capabilities):
                zoomOptions = capabilities.zoomOptions
                exposureRange = capabilities.exposureRange
                flashModes = capabilities.flashModes
                zoomFactor = capabilities.zoomFactor
                phase = .ready
            case .failure:
                phase = .stopped
                camera.stop()
                errorMessage = .cameraErrorUnavailable
            }
        }
    }

    private func setZoom(_ requestedFactor: CGFloat) {
        camera.setZoom(requestedFactor, animated: !reduceMotion) { zoomFactor = $0 }
    }

    private func setExposureBias(_ requestedBias: Double) {
        exposureBias = requestedBias
        camera.setExposureBias(Float(requestedBias)) { result in
            switch result {
            case .success(let value): exposureBias = Double(value)
            case .failure: errorMessage = .cameraErrorExposure
            }
        }
    }

    private func toggleLivePhoto() {
        guard phase == .ready else { return }
        let operationID = UUID()
        phase = .changingLivePhoto(operationID)
        if livePhotoEnabled {
            camera.setLivePhotoEnabled(false) { result in
                guard phase == .changingLivePhoto(operationID) else { return }
                switch result {
                case .success:
                    livePhotoEnabled = false
                    phase = .ready
                case .failure:
                    phase = .stopped
                    camera.stop()
                    errorMessage = .cameraErrorLivePhoto
                }
            }
            return
        }
        Task {
            guard await requestMicrophoneAccess() else {
                guard phase == .changingLivePhoto(operationID) else { return }
                phase = .ready
                errorMessage = .cameraErrorMicrophone
                return
            }
            guard phase == .changingLivePhoto(operationID) else { return }
            camera.setLivePhotoEnabled(true) { result in
                guard phase == .changingLivePhoto(operationID) else { return }
                switch result {
                case .success:
                    livePhotoEnabled = true
                    phase = .ready
                case .failure:
                    phase = .stopped
                    camera.stop()
                    errorMessage = .cameraErrorLivePhoto
                }
            }
        }
    }

    private func capture() {
        guard phase == .ready else { return }
        let ratioAtShutter = captureRatio
        let flashAtShutter = flashMode
        let livePhotoAtShutter = livePhotoEnabled
        let operationID = UUID()
        phase = .capturing(operationID)
        camera.capture(
            ratio: ratioAtShutter,
            livePhoto: livePhotoAtShutter,
            flashMode: flashAtShutter
        ) { result in
            guard phase == .capturing(operationID) else { return }
            phase = .ready
            if case .failure = result { errorMessage = .cameraErrorCapture }
        }
    }
}
