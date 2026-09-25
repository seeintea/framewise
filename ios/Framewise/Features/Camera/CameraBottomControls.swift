//
//  CameraBottomControls.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import SwiftUI

struct CameraMaskOption: Identifiable {
    let id: String
    let title: String
}

struct CameraBottomControls: View {
    let isAlbumEnabled: Bool
    let isCaptureEnabled: Bool
    let canSwitchCamera: Bool
    let onOpenAlbum: () -> Void
    let onCapture: () -> Void
    let onSwitchCamera: () -> Void
    let controlRotation: Angle
    let maskOptions: [CameraMaskOption]
    let selectedMaskId: String
    let onSelectMask: (String) -> Void

    var body: some View {
        Group {
            if maskOptions.count >= 2 {
                VStack(spacing: 24) {
                    captureButton

                    HStack(spacing: 24) {
                        albumButton
                        maskPicker
                        switchCameraButton
                    }
                }
            } else {
                HStack {
                    albumButton
                    Spacer()
                    captureButton
                    Spacer()
                    switchCameraButton
                }
                .frame(height: 72)
            }
        }
    }

    private var maskPicker: some View {
        GeometryReader { geometry in
            CenteredMaskOptionsLayout(selectedIndex: selectedMaskIndex, spacing: 4) {
                ForEach(maskOptions) { option in
                    let isSelected = option.id == selectedMaskId
                    maskOptionButton(option, isSelected: isSelected)
                        .opacity(isSelected ? 0 : 1)
                        .allowsHitTesting(!isSelected)
                        .accessibilityHidden(isSelected)
                }
            }
            .frame(width: geometry.size.width, height: 44)
            .animation(.easeInOut(duration: 0.22), value: selectedMaskId)
            .clipShape(Capsule())
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.13), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.7)
        }
        .overlay {
            if maskOptions.indices.contains(selectedMaskIndex) {
                maskOptionButton(maskOptions[selectedMaskIndex], isSelected: true)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let step = value.translation.width < 0 ? 1 : -1
                    let nextIndex = selectedMaskIndex + step
                    guard maskOptions.indices.contains(nextIndex) else { return }
                    onSelectMask(maskOptions[nextIndex].id)
                }
        )
        .accessibilityElement(children: .contain)
    }

    private var selectedMaskIndex: Int {
        maskOptions.firstIndex { $0.id == selectedMaskId } ?? 0
    }

    @ViewBuilder
    private func maskOptionButton(
        _ option: CameraMaskOption,
        isSelected: Bool
    ) -> some View {
        let button = Button {
            onSelectMask(option.id)
        } label: {
            Text(verbatim: option.title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSelected ? .yellow : .white.opacity(0.78))
                .padding(.horizontal, isSelected ? 12 : 4)
                .frame(minWidth: isSelected ? 60 : 44, minHeight: 30)
        }

        if isSelected {
            if #available(iOS 26.0, *) {
                button
                    .buttonStyle(.glass(.clear))
                    .controlSize(.small)
                    .accessibilityAddTraits(.isSelected)
            } else {
                button
                    .buttonStyle(CameraBottomButtonStyle())
                    .background(.ultraThinMaterial, in: Capsule())
                    .accessibilityAddTraits(.isSelected)
            }
        } else {
            button.buttonStyle(CameraBottomButtonStyle())
        }
    }

    private var albumButton: some View {
        Button(action: onOpenAlbum) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 17, weight: .light))
                .rotationEffect(controlRotation)
                .foregroundStyle(
                    Color(red: 216 / 255, green: 216 / 255, blue: 220 / 255)
                )
                .frame(width: 40, height: 40)
                .background(
                    Color(
                        red: 58.0 / 255.0,
                        green: 58.0 / 255.0,
                        blue: 62.0 / 255.0
                    )
                )
                .clipShape(Circle())
                .padding(2)
                .background(
                    Color(
                        red: 41.0 / 255.0,
                        green: 41.0 / 255.0,
                        blue: 44.0 / 255.0
                    )
                )
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 0.5)
                }
        }
        .buttonStyle(CameraBottomButtonStyle())
        .disabled(!isAlbumEnabled)
        .opacity(isAlbumEnabled ? 1 : 0.45)
        .accessibilityLabel(Text(.cameraAlbumOpen))
    }

    private var captureButton: some View {
        Button(action: onCapture) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.58), lineWidth: 3)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
            }
        }
        .buttonStyle(CameraBottomButtonStyle())
        .disabled(!isCaptureEnabled)
        .opacity(isCaptureEnabled ? 1 : 0.45)
        .accessibilityLabel(Text(.cameraCaptureAccessibilityLabel))
    }

    private var switchCameraButton: some View {
        Button(action: onSwitchCamera) {
            Image(.cameraRotate)
                .resizable()
                .scaledToFit()
                .rotationEffect(controlRotation)
                .foregroundStyle(.white)
                .frame(width: 21, height: 21)
                .frame(width: 44, height: 44)
                .background(
                    Color(
                        red: 41.0 / 255.0,
                        green: 41.0 / 255.0,
                        blue: 44.0 / 255.0
                    )
                )
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.09), lineWidth: 0.5)
                }
        }
        .buttonStyle(CameraBottomButtonStyle())
        .disabled(!canSwitchCamera)
        .opacity(canSwitchCamera ? 1 : 0.45)
        .accessibilityLabel(Text(.cameraSwitchCamera))
    }
}

private struct CameraBottomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct CenteredMaskOptionsLayout: Layout {
    let selectedIndex: Int
    let spacing: CGFloat

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
        guard sizes.indices.contains(selectedIndex) else { return }

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
            place(index, at: rightX)
            rightX += sizes[index].width + spacing
        }
    }
}
