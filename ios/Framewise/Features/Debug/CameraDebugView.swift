#if DEBUG
    import AVFoundation
    import SwiftUI

    struct CameraDebugView: View {
        private struct MockMask: Identifiable {
            let id: String
            let title: String
            let aspectRatio: MaskAspectRatio
        }

        private static let previewMask = try? MaskServer().getMask(
            id: "5aa983db-8730-4307-b18f-88ffe4735206"
        )
        private static let fallbackAspectRatio = MaskAspectRatio(
            width: 3,
            height: 4
        )
        private static let mockMasks = [
            MockMask(
                id: "mask-3-4", title: "3:4",
                aspectRatio: .init(width: 3, height: 4)
            ),
            MockMask(
                id: "mask-9-16", title: "9:16",
                aspectRatio: .init(width: 9, height: 16)
            ),
            MockMask(
                id: "mask-1-1", title: "1:1",
                aspectRatio: .init(width: 1, height: 1)
            ),
            MockMask(
                id: "mask-4-3", title: "4:3",
                aspectRatio: .init(width: 4, height: 3)
            ),
            MockMask(
                id: "mask-16-9", title: "16:9",
                aspectRatio: .init(width: 16, height: 9)
            ),
        ]

        let showsRelatedMasks: Bool

        @State private var isFlashEnabled = false
        @State private var isLivePhotoEnabled = true
        @State private var areAnnotationsVisible = true
        @State private var showsMaskLoadError = false
        @State private var selectedZoomFactor = 1.0
        @State private var selectedExposureBias = 0.0
        @State private var selectedMaskId = "mask-3-4"
        @State private var previewBottom: CGFloat?
        @State private var shutterTop: CGFloat?

        private let zoomFactors = [0.5, 1.0, 2.0, 5.0]

        init(showsRelatedMasks: Bool = true) {
            self.showsRelatedMasks = showsRelatedMasks
        }

        var body: some View {
            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                    + geometry.safeAreaInsets.top
                let layout = CameraViewportLayout(
                    aspectRatio: showsRelatedMasks
                        ? selectedMask.aspectRatio
                        : Self.previewMask?.defaultVariant.aspectRatio
                            ?? Self.fallbackAspectRatio,
                    availableSize: CGSize(
                        width: geometry.size.width,
                        height: availableHeight
                    )
                )

                Color.gray
                    .overlay {
                        ZStack {
                            if !showsRelatedMasks, let mask = Self.previewMask {
                                CameraMaskOverlay(
                                    variant: mask.defaultVariant,
                                    annotationTextById: mask.annotationTextById(
                                        variantId: mask.defaultVariant.id
                                    ),
                                    showsAnnotations: areAnnotationsVisible,
                                    layout: layout
                                )
                            }

                            CameraFocusExposureControl(
                                focusPoint: CGPoint(
                                    x: layout.previewSize.width / 2,
                                    y: layout.previewSize.height / 2
                                ),
                                minimumExposureBias: -2,
                                maximumExposureBias: 2,
                                selectedExposureBias: selectedExposureBias,
                                isExposureEnabled: true,
                                isExposureVisuallyEnabled: true,
                                onSelectExposureBias: {
                                    selectedExposureBias = $0
                                },
                                onExposureInteractionChanged: { _ in },
                                controlRotation: .zero
                            )
                        }
                    }
                    .frame(
                        width: layout.previewSize.width,
                        height: layout.previewSize.height
                    )
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .named("cameraDebug")).maxY
                    } action: { previewBottom = $0 }
                    .overlay(alignment: .bottom) {
                        CameraZoomControls(
                            zoomOptions: zoomFactors.map { factor in
                                CameraEngine.ZoomOption(
                                    factor: CGFloat(factor),
                                    label: "\(factor.formatted(.number.precision(.fractionLength(0...1))))×"
                                )
                            },
                            selectedZoomFactor: CGFloat(selectedZoomFactor),
                            isEnabled: true,
                            onSelectZoomFactor: { selectedZoomFactor = Double($0) },
                            controlRotation: .zero
                        )
                        .padding(.bottom, 12)
                        .offset(y: -zoomLift)
                    }
                    .frame(
                        width: geometry.size.width,
                        height: availableHeight
                    )
                    .offset(y: -geometry.safeAreaInsets.top)
            }
            .background(Color.black.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                CameraBottomControls(
                    isAlbumEnabled: true,
                    isCaptureEnabled: true,
                    canSwitchCamera: true,
                    onOpenAlbum: {},
                    onCapture: {},
                    onSwitchCamera: {},
                    controlRotation: .zero,
                    maskOptions: showsRelatedMasks
                        ? Self.mockMasks.map {
                            CameraMaskOption(id: $0.id, title: $0.title)
                        } : [],
                    selectedMaskId: selectedMaskId,
                    onSelectMask: { selectedMaskId = $0 }
                )
                .padding(.horizontal, 36)
                .padding(.bottom, showsRelatedMasks ? 0 : 16)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .named("cameraDebug")).minY
                } action: { shutterTop = $0 }
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
            .coordinateSpace(name: "cameraDebug")
            .task {
                guard !showsRelatedMasks, Self.previewMask == nil else { return }
                showsMaskLoadError = true
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                showsMaskLoadError = false
            }
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                CameraTopBarControls(
                    flashMode: isFlashEnabled ? .on : .off,
                    availableFlashModes: [.off, .on],
                    onToggleFlash: { isFlashEnabled.toggle() },
                    isLivePhotoEnabled: isLivePhotoEnabled,
                    onToggleLivePhoto: { isLivePhotoEnabled.toggle() },
                    areAnnotationsVisible: areAnnotationsVisible,
                    onToggleAnnotations: { areAnnotationsVisible.toggle() },
                    onMore: {}
                )
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }

        private var selectedMask: MockMask {
            Self.mockMasks.first { $0.id == selectedMaskId } ?? Self.mockMasks[0]
        }

        private var zoomLift: CGFloat {
            guard let previewBottom, let shutterTop else { return 0 }
            let defaultZoomBottom = previewBottom - 12
            return max(0, defaultZoomBottom + 24 - shutterTop)
        }
    }

    #Preview("Related masks") {
        NavigationStack {
            CameraDebugView()
        }
    }

    #Preview("Single mask") {
        NavigationStack {
            CameraDebugView(showsRelatedMasks: false)
        }
    }
#endif
