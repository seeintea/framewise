import CoreMotion
import Photos
import SwiftUI
import UIKit

struct CameraScreen: View {
    @Environment(\.scenePhase) private var scenePhase

    let variant: CompositionTemplateVariant
    let annotationTextById: [String: String]

    @State private var engine = CameraEngine()
    @State private var ratio: PhotoAspectRatio = .standard
    @State private var saveOrientation: PhotoSaveOrientation = .portrait
    @State private var lastLandscapeOrientation: UIDeviceOrientation?
    @State private var zoomOptions: [CameraEngine.ZoomOption] = []
    @State private var zoomFactor: CGFloat = 1
    @State private var pinchStartFactor: CGFloat?
    @State private var isCapturing = false
    @State private var errorMessage: LocalizedStringKey?
    @State private var showsSavedFeedback = false
    @State private var orientationMotion = CMMotionManager()

    var body: some View {
        GeometryReader { geometry in
            let previewWidth = min(geometry.size.width,
                                   geometry.size.height * ratio.value)
            ZStack {
                Color.black.ignoresSafeArea()

                CameraPreview(session: engine.session)
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

                    Spacer()

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
            case .success(let options):
                zoomOptions = options
                if let normal = options.first(where: { $0.label == "1×" }) {
                    zoomFactor = normal.factor
                }
            case .failure: errorMessage = "camera.error.unavailable"
            }
        }
    }

    private func setZoom(_ requestedFactor: CGFloat) {
        engine.setZoom(requestedFactor) { zoomFactor = $0 }
    }

    private var saveOrientationTitle: LocalizedStringKey {
        switch saveOrientation {
        case .portrait: "camera.output.portrait"
        case .landscapeAutomatic: "camera.output.landscape"
        case .landscapeLeft: "camera.output.landscape-left"
        case .landscapeRight: "camera.output.landscape-right"
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
        isCapturing = true
        let selectedRatio = ratio
        let selectedSaveOrientation = saveOrientation
        let deviceOrientation = UIDevice.current.orientation
        let rememberedOrientation = lastLandscapeOrientation
        let motionOrientation = motionLandscapeOrientation
        engine.capture { result in
            switch result {
            case .failure:
                isCapturing = false
                errorMessage = "camera.error.capture"
            case .success(let data):
                guard let portraitImage = selectedRatio.croppedImage(from: data) else {
                    isCapturing = false
                    errorMessage = "camera.error.capture"
                    return
                }
                let image = selectedSaveOrientation.applied(
                    to: portraitImage,
                    deviceOrientation: deviceOrientation,
                    lastLandscapeOrientation: rememberedOrientation,
                    motionLandscapeOrientation: motionOrientation
                )
                Task {
                    do {
                        try await PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        }
                        showsSavedFeedback = true
                        try? await Task.sleep(for: .seconds(1.5))
                        showsSavedFeedback = false
                    } catch {
                        errorMessage = "camera.error.save"
                    }
                    isCapturing = false
                }
            }
        }
    }
}
