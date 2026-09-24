#if DEBUG
    import SwiftUI

    struct CameraDebugView: View {
        private static let previewMask = try? MaskServer().getMask(
            id: "5aa983db-8730-4307-b18f-88ffe4735206"
        )
        private static let fallbackAspectRatio = MaskAspectRatio(
            width: 3,
            height: 4
        )

        @State private var isFlashEnabled = false
        @State private var isLivePhotoEnabled = true
        @State private var areAnnotationsVisible = true
        @State private var showsMaskLoadError = false
        @State private var selectedZoomFactor = 1.0
        @State private var selectedExposureBias = 0.0

        private let zoomFactors = [0.5, 1.0, 2.0, 5.0]

        var body: some View {
            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                    + geometry.safeAreaInsets.top
                let layout = CameraViewportLayout(
                    aspectRatio: Self.previewMask?.defaultVariant.aspectRatio
                        ?? Self.fallbackAspectRatio,
                    availableSize: CGSize(
                        width: geometry.size.width,
                        height: availableHeight
                    )
                )

                Color.gray
                    .overlay {
                        ZStack {
                            if let mask = Self.previewMask {
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
                    .frame(
                        width: geometry.size.width,
                        height: availableHeight
                    )
                    .offset(y: -geometry.safeAreaInsets.top)
            }
            .background(Color.black.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                VStack(spacing: 4) {
                    CameraZoomControls(
                        zoomFactors: zoomFactors,
                        selectedZoomFactor: selectedZoomFactor,
                        isEnabled: true,
                        onSelectZoomFactor: { selectedZoomFactor = $0 },
                        controlRotation: .zero
                    )

                    CameraBottomControls(
                        isAlbumEnabled: false,
                        isCaptureEnabled: true,
                        canSwitchCamera: true,
                        onOpenAlbum: {},
                        onCapture: {},
                        onSwitchCamera: {},
                        controlRotation: .zero
                    )
                }
                .padding(.horizontal, 24)
                .safeAreaPadding(.bottom, 18)
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
            .task {
                guard Self.previewMask == nil else { return }
                showsMaskLoadError = true
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                showsMaskLoadError = false
            }
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                CameraTopBarControls(
                    isFlashEnabled: isFlashEnabled,
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
    }

    #Preview {
        NavigationStack {
            CameraDebugView()
        }
    }
#endif
