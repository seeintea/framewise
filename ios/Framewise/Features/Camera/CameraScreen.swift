import AVFoundation
import CoreMotion
import Photos
import SwiftUI
import UIKit

struct CameraScreen: View {
    private enum SaveError: Error { case invalidPhoto }
    @Environment(\.scenePhase) private var scenePhase

    let variant: MaskVariant
    let annotationTextById: [String: String]
    let requestMicrophoneAccess: () async -> Bool

    @State private var engine = CameraEngine()
    @State private var ratio: PhotoAspectRatio = .standard
    @State private var saveOrientation: PhotoSaveOrientation = .portrait
    @State private var lastLandscapeOrientation: UIDeviceOrientation?
    @State private var zoomOptions: [CameraEngine.ZoomOption] = []
    @State private var zoomFactor: CGFloat = 1
    @State private var pinchStartFactor: CGFloat?
    @State private var exposureRange: ClosedRange<Float> = 0...0
    @State private var exposureBias: Double = 0
    @State private var flashModes: [AVCaptureDevice.FlashMode] = []
    @State private var flashMode: AVCaptureDevice.FlashMode = .off
    @State private var showsFocusFeedback = false
    @State private var focusFeedbackTask: Task<Void, Never>?
    @State private var isCapturing = false
    @State private var isLivePhotoEnabled = false
    @State private var isEnablingLivePhoto = false
    @State private var errorMessage: LocalizedStringKey?
    @State private var showsSavedFeedback = false
    @State private var savedFeedbackTask: Task<Void, Never>?
    @State private var orientationMotion = CMMotionManager()
    private let livePhotoProcessor = LivePhotoProcessor()

    var body: some View {
        GeometryReader { geometry in
            let previewWidth = min(geometry.size.width,
                                   geometry.size.height * ratio.value)
            ZStack {
                Color.black.ignoresSafeArea()

                CameraPreview(session: engine.session) { point in
                    engine.focusAndExpose(at: point) { result in
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
                        Menu {
                            Button("camera.output.portrait") {
                                saveOrientation = .portrait
                            }
                            Button("camera.output.landscape") {
                                saveOrientation = .landscapeAutomatic
                            }
                            Button("camera.output.landscape-left") {
                                saveOrientation = .landscapeLeft
                            }
                            Button("camera.output.landscape-right") {
                                saveOrientation = .landscapeRight
                            }
                        } label: {
                            Text(saveOrientationTitle)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background(.black.opacity(0.55), in: Capsule())
                        }
                        .accessibilityLabel("camera.output.accessibility-label")

                        Spacer()

                        Button(action: toggleLivePhoto) {
                            Image(systemName: isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
                                .font(.title3)
                                .foregroundStyle(isLivePhotoEnabled ? .yellow : .white)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(isEnablingLivePhoto || isCapturing)
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
                        .disabled(flashModes.count < 2 || isCapturing)
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
                    .disabled(isCapturing || zoomOptions.isEmpty)
                    .accessibilityLabel("camera.capture.accessibility-label")
                    .padding(.bottom, 24)
                }

                if showsSavedFeedback {
                    Text("camera.saved.message")
                        .font(.subheadline.weight(.semibold))
                        .padding(12)
                        .background(.black.opacity(0.7), in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 60)
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
        .onAppear {
            lastLandscapeOrientation = nil
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            rememberLandscapeOrientation()
            if orientationMotion.isDeviceMotionAvailable {
                orientationMotion.deviceMotionUpdateInterval = 0.1
                orientationMotion.startDeviceMotionUpdates()
            }
        }
        .task { startCamera() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIDevice.orientationDidChangeNotification
        )) { _ in
            rememberLandscapeOrientation()
        }
        .onDisappear {
            engine.stop()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            orientationMotion.stopDeviceMotionUpdates()
            savedFeedbackTask?.cancel()
            focusFeedbackTask?.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startCamera() }
            else { engine.stop() }
        }
        .alert("camera.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("camera.error.ok", role: .cancel) { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
    }

    private func startCamera() {
        guard Permissions.check([.camera]).isAuthorized else {
            errorMessage = "camera.error.permission"
            return
        }
        engine.start { result in
            switch result {
            case .success(let capabilities):
                zoomOptions = capabilities.zoomOptions
                exposureRange = capabilities.exposureRange
                flashModes = capabilities.flashModes
                if !capabilities.flashModes.contains(flashMode) { flashMode = .off }
                if let normal = capabilities.zoomOptions.first(where: { $0.label == "1×" }) {
                    zoomFactor = normal.factor
                }
            case .failure: errorMessage = "camera.error.unavailable"
            }
        }
    }

    private func setZoom(_ requestedFactor: CGFloat) {
        engine.setZoom(requestedFactor) { zoomFactor = $0 }
    }

    private func setExposureBias(_ requestedBias: Double) {
        exposureBias = requestedBias
        engine.setExposureBias(Float(requestedBias)) { result in
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

    private var saveOrientationTitle: LocalizedStringKey {
        switch saveOrientation {
        case .portrait: "camera.output.portrait"
        case .landscapeAutomatic: "camera.output.landscape"
        case .landscapeLeft: "camera.output.landscape-left"
        case .landscapeRight: "camera.output.landscape-right"
        }
    }

    private var livePhotoAccessibilityLabel: LocalizedStringKey {
        isLivePhotoEnabled ? "camera.live.disable" : "camera.live.enable"
    }

    private func toggleLivePhoto() {
        guard !isEnablingLivePhoto else { return }
        if isLivePhotoEnabled {
            isLivePhotoEnabled = false
            return
        }
        isEnablingLivePhoto = true
        Task {
            guard await requestMicrophoneAccess() else {
                isEnablingLivePhoto = false
                errorMessage = "camera.error.microphone"
                return
            }
            engine.enableLivePhoto { result in
                isEnablingLivePhoto = false
                switch result {
                case .success: isLivePhotoEnabled = true
                case .failure: errorMessage = "camera.error.live-photo"
                }
            }
        }
    }

    private func rememberLandscapeOrientation() {
        let orientation = UIDevice.current.orientation
        if orientation == .landscapeLeft || orientation == .landscapeRight {
            lastLandscapeOrientation = orientation
        }
    }

    private var motionLandscapeOrientation: UIDeviceOrientation? {
        guard let gravity = orientationMotion.deviceMotion?.gravity,
              abs(gravity.x) >= 0.5,
              abs(gravity.x) > abs(gravity.y) else {
            return nil
        }
        // In the portrait screen coordinates, left hold has negative x gravity.
        return gravity.x < 0 ? .landscapeLeft : .landscapeRight
    }

    private func capture() {
        guard !isCapturing else { return }
        savedFeedbackTask?.cancel()
        showsSavedFeedback = false
        isCapturing = true
        let selectedRatio = ratio
        let selectedSaveOrientation = saveOrientation
        let capturesLivePhoto = isLivePhotoEnabled
        let deviceOrientation = UIDevice.current.orientation
        let rememberedOrientation = lastLandscapeOrientation
        let motionOrientation = motionLandscapeOrientation
        let quarterTurns = selectedSaveOrientation.quarterTurns(
            deviceOrientation: deviceOrientation,
            lastLandscapeOrientation: rememberedOrientation,
            motionLandscapeOrientation: motionOrientation
        )
        engine.capture(livePhoto: capturesLivePhoto, flashMode: flashMode) { result in
            switch result {
            case .failure:
                isCapturing = false
                errorMessage = "camera.error.capture"
            case .success(let captured):
                Task {
                    do {
                        try await save(
                            captured,
                            ratio: selectedRatio,
                            saveOrientation: selectedSaveOrientation,
                            deviceOrientation: deviceOrientation,
                            lastLandscapeOrientation: rememberedOrientation,
                            motionLandscapeOrientation: motionOrientation,
                            quarterTurns: quarterTurns
                        )
                        isCapturing = false
                        showsSavedFeedback = true
                        savedFeedbackTask?.cancel()
                        savedFeedbackTask = Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            guard !Task.isCancelled else { return }
                            showsSavedFeedback = false
                        }
                    } catch {
                        errorMessage = "camera.error.save"
                        isCapturing = false
                    }
                }
            }
        }
    }

    private func save(
        _ captured: CameraEngine.CapturedPhoto,
        ratio: PhotoAspectRatio,
        saveOrientation: PhotoSaveOrientation,
        deviceOrientation: UIDeviceOrientation,
        lastLandscapeOrientation: UIDeviceOrientation?,
        motionLandscapeOrientation: UIDeviceOrientation?,
        quarterTurns: Int
    ) async throws {
        switch captured {
        case .still(let data):
            guard let portraitImage = ratio.croppedImage(from: data) else {
                throw SaveError.invalidPhoto
            }
            let image = saveOrientation.applied(
                to: portraitImage,
                deviceOrientation: deviceOrientation,
                lastLandscapeOrientation: lastLandscapeOrientation,
                motionLandscapeOrientation: motionLandscapeOrientation
            )
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        case .live(let photoData, let movieURL):
            defer { try? FileManager.default.removeItem(at: movieURL) }
            let processed = try await livePhotoProcessor.process(
                photoData: photoData,
                movieURL: movieURL,
                ratio: ratio,
                quarterTurns: quarterTurns
            )
            defer {
                if processed.movieURL != movieURL {
                    try? FileManager.default.removeItem(at: processed.movieURL)
                }
            }
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: processed.photoData, options: nil)
                request.addResource(with: .pairedVideo,
                                    fileURL: processed.movieURL, options: nil)
            }
        }
    }
}
