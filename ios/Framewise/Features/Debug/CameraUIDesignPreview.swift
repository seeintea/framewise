#if DEBUG
    import SwiftUI

    /// A UI-only comparison with the 2026-10-02 design; no capture or library access.
    struct CameraUIDesignPreview: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        private enum Ratio: String, CaseIterable {
            case standard = "3:4"
            case square = "1:1"
            case tall = "9:16"

            var next: Ratio {
                switch self {
                case .standard: .square
                case .square: .tall
                case .tall: .standard
                }
            }

            var aspectRatio: MaskAspectRatio {
                switch self {
                case .standard: .init(width: 3, height: 4)
                case .square: .init(width: 1, height: 1)
                case .tall: .init(width: 9, height: 16)
                }
            }
        }

        private enum AdjustmentSheet: String, Identifiable {
            case zoom
            case exposure

            var id: String { rawValue }
        }

        // Match CameraDebugView's five ratio-labelled related-mask fixtures.
        private enum RelatedMask: Int, CaseIterable {
            case standard
            case tall
            case square
            case standardLandscape
            case tallLandscape

            var aspectRatio: MaskAspectRatio {
                switch self {
                case .standard: Ratio.standard.aspectRatio
                case .tall: Ratio.tall.aspectRatio
                case .square: Ratio.square.aspectRatio
                case .standardLandscape: .init(width: 4, height: 3)
                case .tallLandscape: .init(width: 16, height: 9)
                }
            }

            var title: String {
                "\(Int(aspectRatio.width)):\(Int(aspectRatio.height))"
            }
        }

        private static let ink = Color(red: 242 / 255, green: 240 / 255, blue: 228 / 255)
        private static let accent = Color(red: 212 / 255, green: 188 / 255, blue: 137 / 255)

        let showsRelatedMasks: Bool

        @State private var ratio = Ratio.standard
        @State private var selectedRelatedMask = RelatedMask.standard
        @State private var showsRatioPopover = false
        @State private var flashIndex = 0
        @State private var isLivePhotoEnabled = true
        @State private var showsAnnotations = true
        @State private var isFrontCamera = false
        @State private var zoom = 1.0
        @State private var exposureBias = 0.0
        @State private var activeAdjustmentSheet: AdjustmentSheet?
        @State private var shutterTop: CGFloat?
        @State private var previewControlsHeight: CGFloat = 44
        @State private var captureID = UUID()
        @State private var isShutterFeedbackActive = false

        init(showsRelatedMasks: Bool = false) {
            self.showsRelatedMasks = showsRelatedMasks
        }

        var body: some View {
            GeometryReader { geometry in
                let availableHeight = geometry.size.height + geometry.safeAreaInsets.top
                let layout = CameraViewportLayout(
                    aspectRatio: showsRelatedMasks
                        ? selectedRelatedMask.aspectRatio : ratio.aspectRatio,
                    availableSize: CGSize(width: geometry.size.width, height: availableHeight)
                )
                let previewBottom =
                    (availableHeight + layout.previewSize.height) / 2 - geometry.safeAreaInsets.top

                // Match the existing mock's neutral background for the visual comparison.
                Color.gray
                    // Brightness is illustrative only, not a simulation of the capture pipeline.
                    .brightness(exposureBias * 0.12)
                    .overlay {
                        if !showsRelatedMasks {
                            compositionGuide(size: layout.previewSize)
                        }
                    }
                    .overlay {
                        if !reduceMotion {
                            CameraShutterFeedback(
                                captureID: captureID,
                                isLivePhoto: isLivePhotoEnabled,
                                isActive: $isShutterFeedbackActive
                            )
                        }
                    }
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.34)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: min(160, layout.previewSize.height / 3))
                        .allowsHitTesting(false)
                    }
                    .frame(width: layout.previewSize.width, height: layout.previewSize.height)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        previewControls
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: {
                                previewControlsHeight = $0
                            }
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                            .padding(.bottom, 12)
                            .offset(y: -zoomLift(previewBottom: previewBottom))
                    }
                    .frame(width: geometry.size.width, height: availableHeight)
                    .offset(y: -geometry.safeAreaInsets.top)
            }
            .background(Color.black.ignoresSafeArea())
            .overlay(alignment: .top) {
                topControls.padding(.horizontal, 12)
            }
            .overlay(alignment: .bottom) {
                bottomControls
                    .padding(.horizontal, 36)
                    .padding(.bottom, showsRelatedMasks ? 0 : 16)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .named("cameraUIDesignPreview")).minY
                    } action: {
                        shutterTop = $0
                    }
            }
            .coordinateSpace(name: "cameraUIDesignPreview")
            .foregroundStyle(Self.ink)
            .buttonStyle(PreviewButtonStyle())
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .sheet(item: $activeAdjustmentSheet) { sheet in
                Group {
                    switch sheet {
                    case .zoom: zoomSheet
                    case .exposure: exposureSheet
                    }
                }
                .presentationDetents(
                    dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(120), .medium]
                )
                .presentationDragIndicator(.visible)
            }
        }

        private var previewControls: some View {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    zoomControls
                    exposureButton.frame(minWidth: 104)
                    annotationsButton
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        zoomControls
                        annotationsButton
                    }
                    exposureButton.frame(minWidth: 104)
                }
            }
        }

        private var topControls: some View {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text("返回"))
                }
                .frame(width: 88, alignment: .leading)
                Spacer(minLength: 0)
                if !showsRelatedMasks {
                    ratioControl
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Button {
                        flashIndex = (flashIndex + 1) % 3
                    } label: {
                        Image(systemName: flashSymbol)
                            .foregroundStyle(flashIndex == 0 ? Self.ink.opacity(0.72) : Self.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(flashTitle))

                    Button {
                        isLivePhotoEnabled.toggle()
                    } label: {
                        Image(systemName: isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
                            .foregroundStyle(Self.ink.opacity(isLivePhotoEnabled ? 1 : 0.55))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(
                        isLivePhotoEnabled ? Text(.cameraLiveDisable) : Text(.cameraLiveEnable)
                    )
                }
            }
            .font(.system(size: 18, weight: .regular))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        }

        private var ratioControl: some View {
            Button {
                selectRatio(ratio.next)
            } label: {
                Text(verbatim: ratio.rawValue)
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .exclusively(before: TapGesture())
                    .onEnded { gesture in
                        switch gesture {
                        case .first: showsRatioPopover = true
                        case .second: selectRatio(ratio.next)
                        }
                    }
            )
            .accessibilityLabel(Text(.cameraMaskSize))
            .accessibilityValue(Text(verbatim: ratio.rawValue))
            .accessibilityHint(Text("轻点切换画幅，长按选择画幅"))
            .accessibilityAction(named: Text("选择画幅")) {
                showsRatioPopover = true
            }
            .popover(isPresented: $showsRatioPopover, attachmentAnchor: .point(.bottom)) {
                ratioPopover
                    .presentationCompactAdaptation(.popover)
            }
        }

        private var ratioPopover: some View {
            VStack(spacing: 0) {
                ForEach(Ratio.allCases, id: \.self) { option in
                    Button {
                        showsRatioPopover = false
                        selectRatio(option)
                    } label: {
                        HStack(spacing: 24) {
                            Text(verbatim: option.rawValue)
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .opacity(option == ratio ? 1 : 0)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(option == ratio ? Self.accent : Self.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background {
                            if option == ratio {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Self.accent.opacity(0.08))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(option == ratio ? .isSelected : [])
                }
            }
            .font(.subheadline.monospacedDigit())
            .padding(8)
            .frame(minWidth: 140)
            .fixedSize(horizontal: true, vertical: true)
            .buttonStyle(PreviewButtonStyle())
            .preferredColorScheme(.dark)
        }

        private func selectRatio(_ newRatio: Ratio) {
            withAnimation(reduceMotion ? nil : CameraViewportLayout.transitionAnimation) {
                ratio = newRatio
            }
        }

        private var zoomControls: some View {
            let label = "\(zoom.formatted(.number.precision(.fractionLength(0...1))))×"
            return Button {
                cycleZoom()
            } label: {
                Text(verbatim: label)
                    .font(.subheadline.monospacedDigit())
                    .fixedSize()
                    .foregroundStyle(Self.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(Self.accent)
                            .frame(width: 12, height: 1)
                            .padding(.bottom, 6)
                    }
            }
            // Consume either touch gesture; releasing a long press must not cycle the preset.
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .exclusively(before: TapGesture())
                    .onEnded { gesture in
                        switch gesture {
                        case .first: activeAdjustmentSheet = .zoom
                        case .second: cycleZoom()
                        }
                    }
            )
            .accessibilityLabel(Text(.cameraZoomAccessibilityLabel(zoom: label)))
            .accessibilityHint(Text("轻点切换倍率，长按调整倍率"))
            .accessibilityAction(named: Text("调整倍率")) {
                activeAdjustmentSheet = .zoom
            }
        }

        private func cycleZoom() {
            let factors = isFrontCamera ? [1.0, 1.3] : [0.5, 1.0, 2.0]
            zoom = factors.first { $0 > zoom } ?? factors[0]
        }

        private var exposureButton: some View {
            Button {
                activeAdjustmentSheet = .exposure
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 18, weight: .regular))
                    if exposureBias != 0 {
                        Text(verbatim: exposureValue)
                            .font(.footnote.monospaced())
                            .fixedSize()
                    }
                }
                .foregroundStyle(exposureBias == 0 ? Self.ink : Self.accent)
                .padding(.horizontal, exposureBias == 0 ? 0 : 10)
                .frame(minHeight: 32)
                .background {
                    if exposureBias != 0 {
                        Capsule()
                            .fill(.black.opacity(0.32))
                            .overlay {
                                Capsule()
                                    .strokeBorder(Self.ink.opacity(0.18), lineWidth: 0.5)
                            }
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Capsule())
            }
            .accessibilityLabel(Text(.cameraExposureLabel))
            .accessibilityValue(Text(verbatim: exposureLabel))
            .accessibilityHint(Text("打开曝光调整"))
        }

        private var annotationsButton: some View {
            Button {
                showsAnnotations.toggle()
            } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(showsAnnotations ? Self.accent : Self.ink.opacity(0.65))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(
                showsAnnotations ? Text(.cameraAnnotationsHide) : Text(.cameraAnnotationsShow)
            )
        }

        private var zoomSheet: some View {
            Slider(
                value: Binding(
                    get: { zoom },
                    set: { zoom = ($0 * 10).rounded() / 10 }
                ),
                in: isFrontCamera ? 1...1.3 : 0.5...2,
                step: isFrontCamera ? 0.3 : 0.1
            ) {
                Text("倍率")
            }
            .accessibilityValue(
                Text(verbatim: "\(zoom.formatted(.number.precision(.fractionLength(0...1))))×")
            )
            .frame(minHeight: 44)
            .padding(.horizontal, 24)
            .tint(Self.accent)
            .preferredColorScheme(.dark)
        }

        private var exposureSheet: some View {
            Slider(
                value: Binding(
                    get: { exposureBias },
                    set: { exposureBias = ($0 * 10).rounded() / 10 }
                ),
                in: -2...2,
                step: 0.1
            ) {
                Text(.cameraExposureLabel)
            }
            .accessibilityValue(Text(verbatim: exposureLabel))
            .frame(minHeight: 44)
            .padding(.horizontal, 24)
            .tint(Self.accent)
            .preferredColorScheme(.dark)
        }

        private var exposureValue: String {
            String(format: "%+.1f", exposureBias)
        }

        private var exposureLabel: String {
            "\(exposureValue) EV"
        }

        private var bottomControls: some View {
            Group {
                if showsRelatedMasks {
                    VStack(spacing: 16) {
                        captureControlsRow
                        relatedMaskPicker
                    }
                } else {
                    captureControlsRow
                }
            }
        }

        private var captureControlsRow: some View {
            HStack {
                albumPlaceholder
                Spacer()
                captureButton
                Spacer()
                switchCameraButton
            }
            .frame(height: 74)
        }

        private var albumPlaceholder: some View {
            // The album is a visual placeholder, without access to Photos.
            Image(systemName: "photo")
                .font(.system(size: 18, weight: .light))
                .frame(width: 38, height: 38)
                .background(Color.gray.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Self.ink.opacity(0.45), lineWidth: 0.7)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel(Text(.cameraAlbumOpen))
        }

        private var captureButton: some View {
            Button {
                captureID = UUID()
            } label: {
                let label = Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
                    .frame(width: 72, height: 72)
                    .contentShape(Circle())

                if #available(iOS 26.0, *) {
                    label
                        .glassEffect(.regular, in: Circle())
                } else {
                    label
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                        }
                }
            }
            .buttonStyle(.plain)
            .disabled(isShutterFeedbackActive)
            .accessibilityLabel(Text(.cameraCaptureAccessibilityLabel))
        }

        private var switchCameraButton: some View {
            Button {
                isFrontCamera.toggle()
                zoom = 1
            } label: {
                Image(.cameraRotate)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 23)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(.cameraSwitchCamera))
        }

        private var relatedMaskPicker: some View {
            GeometryReader { geometry in
                RelatedMaskOptionsLayout(selectedIndex: selectedRelatedMask.rawValue) {
                    ForEach(RelatedMask.allCases, id: \.self) { mask in
                        Button {
                            selectRelatedMask(mask)
                        } label: {
                            Text(verbatim: mask.title)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(
                                    mask == selectedRelatedMask
                                        ? Self.accent : Self.ink.opacity(0.65)
                                )
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 8)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                                .overlay(alignment: .bottom) {
                                    if mask == selectedRelatedMask {
                                        Capsule()
                                            .fill(Self.accent)
                                            .frame(width: 12, height: 1)
                                            .padding(.bottom, 3)
                                    }
                                }
                        }
                        .accessibilityAddTraits(mask == selectedRelatedMask ? .isSelected : [])
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let step = value.translation.width < 0 ? 1 : -1
                            let nextIndex = selectedRelatedMask.rawValue + step
                            if let mask = RelatedMask(rawValue: nextIndex) {
                                selectRelatedMask(mask)
                            }
                        }
                )
            }
            .frame(height: 44)
            .accessibilityElement(children: .contain)
        }

        private func selectRelatedMask(_ mask: RelatedMask) {
            withAnimation(reduceMotion ? nil : CameraViewportLayout.transitionAnimation) {
                selectedRelatedMask = mask
            }
        }

        private func compositionGuide(size: CGSize) -> some View {
            // Mock geometry only: these ratios are not added to any real template.
            Circle()
                .strokeBorder(Self.ink.opacity(0.48), lineWidth: 1)
                .frame(width: size.width * 0.6, height: size.width * 0.6)
                .overlay {
                    if showsAnnotations {
                        Text("主体")
                            .font(.caption)
                            .foregroundStyle(Self.ink)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }

        private func zoomLift(previewBottom: CGFloat) -> CGFloat {
            guard let shutterTop else { return 0 }
            return max(0, previewBottom - 12 + previewControlsHeight / 2 - shutterTop)
        }

        private var flashSymbol: String {
            switch flashIndex {
            case 1: "bolt"
            case 2: "bolt.fill"
            default: "bolt.slash"
            }
        }

        private var flashTitle: LocalizedStringResource {
            switch flashIndex {
            case 1: .cameraFlashAuto
            case 2: .cameraFlashOn
            default: .cameraFlashOff
            }
        }

        private struct PreviewButtonStyle: ButtonStyle {
            @Environment(\.accessibilityReduceMotion) private var reduceMotion

            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .opacity(configuration.isPressed ? 0.65 : 1)
                    .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.12),
                        value: configuration.isPressed
                    )
            }
        }

        // Keep the selected fixture centered, as CameraBottomControls does in related-mask mode.
        private struct RelatedMaskOptionsLayout: Layout {
            let selectedIndex: Int
            private let spacing: CGFloat = 4

            func sizeThatFits(
                proposal: ProposedViewSize,
                subviews: Subviews,
                cache: inout ()
            ) -> CGSize {
                let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
                return CGSize(
                    width: proposal.width
                        ?? sizes.reduce(0) { $0 + $1.width }
                        + spacing * CGFloat(max(subviews.count - 1, 0)),
                    height: proposal.height ?? sizes.map(\.height).max() ?? 0
                )
            }

            func placeSubviews(
                in bounds: CGRect,
                proposal: ProposedViewSize,
                subviews: Subviews,
                cache: inout ()
            ) {
                let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

                func place(_ index: Int, at x: CGFloat) {
                    subviews[index].place(
                        at: CGPoint(x: x, y: bounds.midY - sizes[index].height / 2),
                        proposal: ProposedViewSize(sizes[index])
                    )
                }

                let selectedX = bounds.midX - sizes[selectedIndex].width / 2
                place(selectedIndex, at: selectedX)

                var leftX = selectedX
                for index in (0..<selectedIndex).reversed() {
                    leftX -= sizes[index].width + spacing
                    place(index, at: leftX)
                }

                var rightX = selectedX + sizes[selectedIndex].width + spacing
                for index in (selectedIndex + 1)..<subviews.count {
                    rightX += spacing
                    place(index, at: rightX)
                    rightX += sizes[index].width
                }
            }
        }
    }
    //
    //    #Preview("Current camera UI") {
    //        NavigationStack {
    //            CameraDebugView(showsRelatedMasks: false)
    //        }
    //    }

    #Preview("Camera UI design comparison") {
        NavigationStack {
            CameraUIDesignPreview()
        }
    }

    #Preview("Camera UI design · Related masks") {
        NavigationStack {
            CameraUIDesignPreview(showsRelatedMasks: true)
        }
    }
#endif
