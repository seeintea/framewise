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

    let variant: MaskVariant
    let annotationTextById: [String: String]
    let requestMicrophoneAccess: () async -> Bool
    @Binding var livePhotoEnabled: Bool

    @State private var camera = CameraController()
    @State private var phase: CameraPhase = .stopped
    @State private var ratio: PhotoAspectRatio = .standard
    @State private var zoomOptions: [CameraEngine.ZoomOption] = []
    @State private var zoomFactor: CGFloat = 1
    @State private var pinchStartFactor: CGFloat?
    @State private var exposureRange: ClosedRange<Float> = 0...0
    @State private var exposureBias: Double = 0
    @State private var flashModes: [AVCaptureDevice.FlashMode] = []
    @State private var flashMode: AVCaptureDevice.FlashMode = .off
    @State private var showsFocusFeedback = false
    @State private var focusFeedbackTask: Task<Void, Never>?
    @State private var errorMessage: LocalizedStringKey?

    var body: some View {
        GeometryReader { geometry in
            let previewWidth = min(geometry.size.width,
                                   geometry.size.height * ratio.value)
            ZStack {
                Color.black.ignoresSafeArea()

                CameraPreview(session: camera.session) { point in
                    camera.focusAndExpose(at: point) { result in
                        switch result {
                        case .success:
                            showsFocusFeedback = true
                            focusFeedbackTask?.cancel()
                            focusFeedbackTask = Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                guard !Task.isCancelled else { return }
                                showsFocusFeedback = false
                            }
                        case .failure:
                            errorMessage = "camera.error.focus"
                        }
                    }
                }
                    .frame(width: previewWidth,
                           height: previewWidth / ratio.value)
                    .clipped()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let baseline = pinchStartFactor ?? zoomFactor
                                if pinchStartFactor == nil { pinchStartFactor = baseline }
                                setZoom(baseline * value)
                            }
                            .onEnded { _ in pinchStartFactor = nil }
                    )

                VStack(spacing: 0) {
                    HStack {
                        Spacer()

                        Button(action: toggleLivePhoto) {
                            Image(systemName: livePhotoEnabled ? "livephoto" : "livephoto.slash")
                                .font(.title3)
                                .foregroundStyle(livePhotoEnabled ? .yellow : .white)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(phase != .ready)
                        .accessibilityLabel(livePhotoAccessibilityLabel)

                        Spacer()
                        Menu {
                            ForEach(PhotoAspectRatio.allCases) { option in
                                Button(option.rawValue) { ratio = option }
                            }
                        } label: {
                            Text(ratio.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background(.black.opacity(0.55), in: Capsule())
                        }
                        .accessibilityLabel("camera.ratio.accessibility-label")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    HStack {
                        Menu {
                            if flashModes.contains(.off) {
                                Button("camera.flash.off") { flashMode = .off }
                            }
                            if flashModes.contains(.auto) {
                                Button("camera.flash.auto") { flashMode = .auto }
                            }
                            if flashModes.contains(.on) {
                                Button("camera.flash.on") { flashMode = .on }
                            }
                        } label: {
                            Text(flashModeTitle)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background(.black.opacity(0.55), in: Capsule())
                        }
                        .disabled(flashModes.count < 2 || phase != .ready)
                        .accessibilityLabel("camera.flash.accessibility-label")
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    if exposureRange.lowerBound < exposureRange.upperBound {
                        HStack(spacing: 12) {
                            Text("camera.exposure.label")
                            Slider(value: Binding(
                                get: { exposureBias },
                                set: { setExposureBias($0) }
                            ), in: Double(exposureRange.lowerBound)...Double(exposureRange.upperBound))
                            .tint(.yellow)
                            Text(verbatim: String(format: "%+.1f", exposureBias))
                                .monospacedDigit()
                                .frame(width: 44)
                            Button("camera.exposure.reset") { setExposureBias(0) }
                        }
                        .font(.caption)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55))
                    }

                    HStack(spacing: 18) {
                        ForEach(zoomOptions, id: \.label) { option in
                            Button {
                                setZoom(option.factor)
                            } label: {
                                Text(verbatim: option.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(
                                        abs(option.factor - zoomFactor) < 0.1
                                            ? .yellow : .white
                                    )
                                    .frame(minWidth: 42, minHeight: 42)
                                    .background(.black.opacity(0.5), in: Circle())
                            }
                            .accessibilityLabel(Text(verbatim: option.label))
                        }
                    }
                    .padding(.bottom, 16)

                    Button(action: capture) {
                        Circle()
                            .fill(.white)
                            .frame(width: 68, height: 68)
                            .padding(5)
                            .overlay {
                                Circle().stroke(.white, lineWidth: 3)
                            }
                    }
                    .disabled(phase != .ready || zoomOptions.isEmpty)
                    .accessibilityLabel("camera.capture.accessibility-label")
                    .padding(.bottom, 24)
                }

                if showsFocusFeedback {
                    Text("camera.focus.applied")
                        .font(.caption.weight(.semibold))
                        .padding(8)
                        .background(.black.opacity(0.7), in: Capsule())
                }
            }
            .foregroundStyle(.white)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { startCamera() }
        .onDisappear {
            phase = .stopped
            camera.stop()
            focusFeedbackTask?.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startCamera() }
            else {
                self.phase = .stopped
                camera.stop()
            }
        }
        .alert("camera.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("camera.error.ok", role: .cancel) { errorMessage = nil }
            if phase == .stopped {
                Button("camera.access.action.retry") {
                    errorMessage = nil
                    startCamera()
                }
                if livePhotoEnabled {
                    Button("camera.live.disable") {
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

    private func startCamera() {
        guard phase == .stopped else { return }
        guard Permissions.check([.camera]).isAuthorized else {
            errorMessage = "camera.error.permission"
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
                if !capabilities.flashModes.contains(flashMode) { flashMode = .off }
                if let normal = capabilities.zoomOptions.first(where: { $0.label == "1×" }) {
                    zoomFactor = normal.factor
                }
                phase = .ready
            case .failure:
                phase = .stopped
                camera.stop()
                errorMessage = "camera.error.unavailable"
            }
        }
    }

    private func setZoom(_ requestedFactor: CGFloat) {
        camera.setZoom(requestedFactor) { zoomFactor = $0 }
    }

    private func setExposureBias(_ requestedBias: Double) {
        exposureBias = requestedBias
        camera.setExposureBias(Float(requestedBias)) { result in
            switch result {
            case .success(let value): exposureBias = Double(value)
            case .failure: errorMessage = "camera.error.exposure"
            }
        }
    }

    private var flashModeTitle: LocalizedStringKey {
        switch flashMode {
        case .off: "camera.flash.off"
        case .auto: "camera.flash.auto"
        case .on: "camera.flash.on"
        @unknown default: "camera.flash.off"
        }
    }

    private var livePhotoAccessibilityLabel: LocalizedStringKey {
        livePhotoEnabled ? "camera.live.disable" : "camera.live.enable"
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
                    errorMessage = "camera.error.live-photo"
                }
            }
            return
        }
        Task {
            guard await requestMicrophoneAccess() else {
                guard phase == .changingLivePhoto(operationID) else { return }
                phase = .ready
                errorMessage = "camera.error.microphone"
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
                    errorMessage = "camera.error.live-photo"
                }
            }
        }
    }

    private func capture() {
        guard phase == .ready else { return }
        let operationID = UUID()
        phase = .capturing(operationID)
        camera.capture(ratio: ratio, livePhoto: livePhotoEnabled, flashMode: flashMode) { result in
            guard phase == .capturing(operationID) else { return }
            phase = .ready
            if case .failure = result { errorMessage = "camera.error.capture" }
        }
    }
}
