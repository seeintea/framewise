//
//  CameraView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import SwiftUI

struct CameraView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let variant: CompositionTemplateVariant
    var annotationTextById: [String: String] = [:]
    @Binding var areAnnotationsVisible: Bool

    @StateObject private var cameraModel = CameraModel()
    @State private var didControlAnnotationVisibility = false
    @State private var controlRotation = Angle.zero
    @State private var hasReceivedControlRotation = false
    @State private var isShutterFlashVisible = false
    @State private var shutterFeedbackTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let previewLayout = previewLayout(in: proxy.size)
            let previewSize = previewLayout.size

            ZStack {
                Color.black

                ZStack {
                    Color(
                        red: 36.0 / 255.0,
                        green: 36.0 / 255.0,
                        blue: 39.0 / 255.0
                    )

                    CameraPreview(
                        session: cameraModel.session,
                        position: cameraModel.capabilities.position,
                        zoomFactor:
                            cameraModel.capabilities.selectedZoomFactor,
                        minimumZoomFactor:
                            cameraModel.capabilities.minimumZoomFactor,
                        maximumZoomFactor:
                            cameraModel.capabilities.maximumZoomFactor,
                        isZoomEnabled:
                            cameraModel.state == .ready,
                        onFocus: { previewPoint, devicePoint in
                            cameraModel.focus(
                                previewPoint: previewPoint,
                                devicePoint: devicePoint
                            )
                        },
                        onZoomFactorChanged: cameraModel.updateZoomFactor,
                        onCaptureRotationAngleChanged:
                            cameraModel.updateCaptureRotationAngle,
                        onControlRotationAngleChanged:
                            updateControlRotation
                    )
                        .accessibilityHidden(true)
                        .opacity(
                            cameraModel.configurationActivity
                                == .switchingCamera ? 0.25 : 1
                        )
                        .animation(
                            .easeInOut(duration: 0.18),
                            value: cameraModel.configurationActivity
                        )

                    CompositionCanvas(
                        variant: variant,
                        annotationTextById: annotationTextById,
                        showsAnnotations: areAnnotationsVisible
                    )
                    .frame(
                        width: previewLayout.compositionSize.width,
                        height: previewLayout.compositionSize.height
                    )
                    .rotationEffect(previewLayout.compositionRotation)
                    .allowsHitTesting(false)

                    if let focusPoint = cameraModel.focusPoint {
                        CameraFocusExposureControl(
                            focusPoint: focusPoint,
                            minimumExposureBias:
                                cameraModel.capabilities.minimumExposureBias,
                            maximumExposureBias:
                                cameraModel.capabilities.maximumExposureBias,
                            selectedExposureBias:
                                cameraModel.capabilities.selectedExposureBias,
                            isExposureEnabled:
                                cameraModel.state == .ready
                                && cameraModel.capabilities
                                    .isExposureBiasAvailable,
                            onSelectExposureBias:
                                cameraModel.selectExposureBias,
                            onExposureInteractionChanged:
                                cameraModel.setExposureInteractionActive,
                            controlRotation: controlRotation
                        )
                            .transition(.opacity)
                    }

                    Color.white
                        .opacity(isShutterFlashVisible ? 0.72 : 0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    cameraStatusOverlay

                    if let issue = cameraModel.livePhotoIssue {
                        VStack {
                            livePhotoIssueNotice(issue)
                                .padding(.horizontal, 16)
                                .padding(.top, 72)

                            Spacer()
                        }
                    }

                }
                .frame(width: previewSize.width, height: previewSize.height)
                .overlay(alignment: .top) {
                    topStatusBadge
                        .rotationEffect(controlRotation)
                        .padding(
                            .top,
                            isDeviceLandscape ? 50 : 12
                        )
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.9)
                            )
                        )
                        .allowsHitTesting(false)
                }
                .clipped()
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                if cameraModel.capabilities.zoomFactors.count > 1 {
                    CameraZoomControls(
                        zoomFactors: cameraModel.capabilities.zoomFactors,
                        selectedZoomFactor:
                            cameraModel.capabilities.selectedZoomFactor,
                        isEnabled: cameraModel.state == .ready,
                        onSelectZoomFactor: cameraModel.selectZoomFactor,
                        controlRotation: controlRotation
                    )
                }

                CameraBottomControls(
                    isCaptureEnabled: cameraModel.state == .ready,
                    canSwitchCamera:
                        cameraModel.capabilities.canSwitchCamera
                        && cameraModel.state == .ready,
                    onCapture: {
                        cameraModel.capturePhoto(
                            outputAspectRatio: templateAspectRatio
                        )
                    },
                    onSwitchCamera: cameraModel.switchCamera,
                    controlRotation: controlRotation
                )
            }
            .padding(.horizontal, 24)
            .safeAreaPadding(.bottom, 18)
        }
        .toolbar {
            CameraToolbarControls(
                isLivePhotoEnabled: cameraModel.isLivePhotoEnabled,
                isLivePhotoControlEnabled: cameraModel.state == .ready,
                onToggleLivePhoto: cameraModel.toggleLivePhoto,
                isFlashEnabled: cameraModel.isFlashEnabled,
                isFlashAvailable:
                    cameraModel.capabilities.isFlashAvailable
                    && cameraModel.state == .ready,
                onToggleFlash: cameraModel.toggleFlash,
                areAnnotationsVisible: $areAnnotationsVisible,
                controlRotation: controlRotation
            )
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                await cameraModel.start()
            case .background:
                await cameraModel.stop()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onDisappear {
            shutterFeedbackTask?.cancel()
            Task {
                await cameraModel.stop()
            }
        }
        .task {
            guard areAnnotationsVisible else {
                return
            }

            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }

            guard !didControlAnnotationVisibility else {
                return
            }

            areAnnotationsVisible = false
        }
        .onChange(of: areAnnotationsVisible) { _, _ in
            didControlAnnotationVisibility = true
        }
        .onChange(of: cameraModel.captureFeedbackTrigger) { _, _ in
            playShutterFeedback()
        }
        .sensoryFeedback(
            .impact(weight: .light),
            trigger: cameraModel.captureFeedbackTrigger
        )
    }

    private func updateControlRotation(_ angle: Double) {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlRotation = .degrees(angle)
            hasReceivedControlRotation = true
        }
    }

    private var shouldShowOrientationHint: Bool {
        guard hasReceivedControlRotation,
              abs(templateAspectRatio - 1) > 0.001 else {
            return false
        }

        let isTemplateLandscape = templateAspectRatio > 1
        return isTemplateLandscape != isDeviceLandscape
    }

    private var isDeviceLandscape: Bool {
        let normalizedAngle = abs(
            controlRotation.degrees.truncatingRemainder(dividingBy: 180)
        )
        return abs(normalizedAngle - 90) < 0.5
    }

    @ViewBuilder
    private var topStatusBadge: some View {
        if cameraModel.livePhotoIssue == nil {
            if let notice = cameraModel.transientNotice {
                switch notice.kind {
                case .livePhotoEnabled:
                    StatusBadge(title: "实况")
                case .livePhotoDisabled:
                    StatusBadge(title: "关闭实况", palette: .light)
                }
            } else if shouldShowOrientationHint {
                StatusBadge(title: "请旋转手机")
            }
        }
    }

    private func playShutterFeedback() {
        shutterFeedbackTask?.cancel()
        guard !reduceMotion else {
            isShutterFlashVisible = false
            return
        }

        withAnimation(.linear(duration: 0.04)) {
            isShutterFlashVisible = true
        }

        shutterFeedbackTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(70))
            } catch {
                return
            }

            withAnimation(.easeOut(duration: 0.16)) {
                isShutterFlashVisible = false
            }
        }
    }

    @ViewBuilder
    private var cameraStatusOverlay: some View {
        switch cameraModel.state {
        case .idle, .ready:
            EmptyView()
        case .requestingAuthorization:
            statusPanel {
                ProgressView()
                    .tint(.white)
                Text("正在请求相机权限")
            }
        case .requestingMicrophoneAuthorization:
            statusPanel {
                ProgressView()
                    .tint(.white)
                Text("正在请求麦克风权限")
                Text("麦克风仅用于录制实况照片的声音")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .configuring:
            if cameraModel.configurationActivity == .startup {
                statusPanel {
                    ProgressView()
                        .tint(.white)
                    Text("正在启动相机")
                }
            }
        case .capturing, .saving:
            EmptyView()
        case .interrupted:
            statusPanel {
                Image(systemName: "camera.fill")
                    .font(.title2)
                Text("相机暂时不可用")
                    .font(.headline)
                Text("系统恢复相机后会自动继续预览")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .unavailable:
            statusPanel {
                Image(systemName: "camera.slash")
                    .font(.title2)
                Text("此设备没有可用相机")
                    .font(.headline)
                Text("模拟器不提供相机预览，请使用真机验证")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                retryButton
            }
        case .failed(let error):
            statusPanel {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                Text(errorTitle(error))
                    .font(.headline)
                errorMessage(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if error.settingsCanResolve {
                    Button("打开设置", action: openSettings)
                        .buttonStyle(.borderedProminent)
                } else if error.canRetry {
                    retryButton
                }
            }
        }
    }

    private func livePhotoIssueNotice(_ issue: LivePhotoIssue) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "livephoto.slash")
                .foregroundStyle(.yellow)

            livePhotoIssueMessage(issue)
                .font(.footnote)
                .foregroundStyle(.white)

            Spacer(minLength: 4)

            if issue.settingsCanResolve {
                Button("设置", action: openSettings)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.yellow)
            }

            Button(action: cameraModel.dismissLivePhotoIssue) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("关闭提示")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func livePhotoIssueMessage(_ issue: LivePhotoIssue) -> some View {
        switch issue {
        case .microphoneDenied:
            Text("麦克风权限未开启，已使用普通照片")
        case .microphoneRestricted:
            Text("麦克风受到系统限制，已使用普通照片")
        case .unsupported:
            Text("当前设备或相机配置不支持实况照片")
        }
    }

    private func statusPanel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.black.opacity(0.72)

            VStack(spacing: 12) {
                content()
            }
            .foregroundStyle(.white)
            .padding(24)
        }
    }

    private var retryButton: some View {
        Button("重试") {
            cameraModel.retry()
        }
        .buttonStyle(.borderedProminent)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(url)
    }

    private func errorTitle(_ error: CameraError) -> LocalizedStringKey {
        switch error {
        case .authorizationDenied, .authorizationRestricted:
            "无法使用相机"
        case .noCameraAvailable:
            "此设备没有可用相机"
        case .cannotCreateInput,
             .cannotAddInput,
             .cannotAddPhotoOutput,
             .cannotStartSession:
            "相机启动失败"
        case .captureNotReady,
             .captureFailed,
             .photoDataUnavailable,
             .processingFailed:
            "拍摄失败"
        case .photoLibraryAuthorizationDenied,
             .photoLibraryAuthorizationRestricted:
            "无法保存照片"
        case .photoLibrarySaveFailed:
            "保存失败"
        case .runtimeError:
            "相机发生错误"
        }
    }

    @ViewBuilder
    private func errorMessage(_ error: CameraError) -> some View {
        switch error {
        case .authorizationDenied:
            Text("请在系统设置中允许 Framewise 使用相机。")
        case .authorizationRestricted:
            Text("此设备限制了相机访问，请检查系统限制设置。")
        case .noCameraAvailable:
            Text("当前没有可用于拍摄的相机。")
        case .cannotCreateInput(let detail), .runtimeError(let detail):
            Text(verbatim: detail)
        case .cannotAddInput:
            Text("无法把相机连接到拍摄会话。")
        case .cannotAddPhotoOutput:
            Text("无法配置照片输出。")
        case .cannotStartSession:
            Text("无法启动相机预览，请稍后重试。")
        case .captureNotReady:
            Text("相机尚未准备好，请稍后重试。")
        case .captureFailed(let detail), .photoLibrarySaveFailed(let detail):
            Text(verbatim: detail)
        case .photoDataUnavailable:
            Text("相机没有返回可保存的照片数据。")
        case .processingFailed(let detail):
            Text(verbatim: detail)
        case .photoLibraryAuthorizationDenied:
            Text("请在系统设置中允许 Framewise 向相册添加照片。")
        case .photoLibraryAuthorizationRestricted:
            Text("此设备限制了相册写入，请检查系统限制设置。")
        }
    }

    private var templateAspectRatio: Double {
        variant.aspectRatio.width / variant.aspectRatio.height
    }

    private func previewLayout(in availableSize: CGSize) -> PreviewLayout {
        let nativeRatio = CGFloat(templateAspectRatio)
        let nativeSize = aspectFitSize(
            ratio: nativeRatio,
            in: availableSize
        )
        let rotatedSize = aspectFitSize(
            ratio: 1 / nativeRatio,
            in: availableSize
        )

        guard rotatedSize.width * rotatedSize.height
            > nativeSize.width * nativeSize.height else {
            return PreviewLayout(
                size: nativeSize,
                compositionSize: nativeSize,
                compositionRotation: .zero
            )
        }

        return PreviewLayout(
            size: rotatedSize,
            compositionSize: CGSize(
                width: rotatedSize.height,
                height: rotatedSize.width
            ),
            compositionRotation: .degrees(90)
        )
    }

    private func aspectFitSize(
        ratio: CGFloat,
        in availableSize: CGSize
    ) -> CGSize {
        let heightFromAvailableWidth = availableSize.width / ratio

        if heightFromAvailableWidth <= availableSize.height {
            return CGSize(
                width: availableSize.width,
                height: heightFromAvailableWidth
            )
        }

        return CGSize(
            width: availableSize.height * ratio,
            height: availableSize.height
        )
    }
}

private struct PreviewLayout {
    let size: CGSize
    let compositionSize: CGSize
    let compositionRotation: Angle
}

#Preview {
    @Previewable @State var areAnnotationsVisible = true

    if let catalog = try? CompositionCatalog(),
        let template = catalog.template(
            id: "34e35f2a-0222-4a35-a97a-d11e6281c2fd"
        ),
        let variant = template.defaultVariant
    {
        CameraView(
            variant: variant,
            annotationTextById: catalog.annotationTextById(
                templateId: template.id,
                variantId: variant.id
            ),
            areAnnotationsVisible: $areAnnotationsVisible
        )
    } else {
        ContentUnavailableView(
            "无法加载构图模版",
            systemImage: "camera"
        )
    }
}
