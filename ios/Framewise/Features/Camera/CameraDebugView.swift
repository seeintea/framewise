//
//  CameraDebugView.swift
//  Framewise
//
//  Created by Codex on 2026/9/15.
//

import SwiftUI

struct CameraDebugView: View {
    @State private var isLivePhotoEnabled = true
    @State private var isFlashEnabled = false
    @State private var areAnnotationsVisible = true
    @State private var isFrontFacing = false
    @State private var selectedZoomFactor = 24.5
    @State private var selectedExposureBias = 0.0
    @State private var showsCaptureFeedback = false

    private let zoomFactors = [0.5, 1.0, 2.0, 5.0]

    var body: some View {
        GeometryReader { proxy in
            let previewSize = previewSize(in: proxy.size)

            ZStack {
                Color.black

                CameraDebugPreview(
                    areAnnotationsVisible: areAnnotationsVisible,
                    isFrontFacing: isFrontFacing,
                    selectedZoomFactor: selectedZoomFactor,
                    selectedExposureBias: selectedExposureBias,
                    onSelectExposureBias: { selectedExposureBias = $0 }
                )
                .frame(width: previewSize.width, height: previewSize.height)
                .clipped()

                if showsCaptureFeedback {
                    captureFeedback
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                CameraZoomControls(
                    zoomFactors: zoomFactors,
                    selectedZoomFactor: selectedZoomFactor,
                    isEnabled: true,
                    onSelectZoomFactor: { selectedZoomFactor = $0 }
                )

                CameraBottomControls(
                    isCaptureEnabled: true,
                    canSwitchCamera: true,
                    onCapture: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsCaptureFeedback.toggle()
                        }
                    },
                    onSwitchCamera: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFrontFacing.toggle()
                        }
                    }
                )
            }
            .padding(.horizontal, 24)
            .safeAreaPadding(.bottom, 18)
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            CameraToolbarControls(
                isLivePhotoEnabled: isLivePhotoEnabled,
                isLivePhotoControlEnabled: true,
                onToggleLivePhoto: { isLivePhotoEnabled.toggle() },
                isFlashEnabled: isFlashEnabled,
                isFlashAvailable: true,
                onToggleFlash: { isFlashEnabled.toggle() },
                areAnnotationsVisible: $areAnnotationsVisible
            )
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Camera Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var captureFeedback: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.green)

            Text("拍摄反馈预览")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            .black.opacity(0.74),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private func previewSize(in availableSize: CGSize) -> CGSize {
        let ratio = 3.0 / 4.0
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

private struct CameraDebugPreview: View {
    let areAnnotationsVisible: Bool
    let isFrontFacing: Bool
    let selectedZoomFactor: Double
    let selectedExposureBias: Double
    let onSelectExposureBias: (Double) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.18, blue: 0.28),
                    Color(red: 0.31, green: 0.37, blue: 0.42),
                    Color(red: 0.12, green: 0.16, blue: 0.12),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 180, height: 180)
                .offset(x: 70, y: -130)

            RoundedRectangle(cornerRadius: 120)
                .fill(.black.opacity(0.28))
                .frame(width: 220, height: 330)
                .offset(x: isFrontFacing ? -40 : 40, y: 110)
                .scaleEffect(1 + (selectedZoomFactor - 1) * 0.04)

            if areAnnotationsVisible {
                CameraDebugGuide()
                    .transition(.opacity)
            }

            GeometryReader { proxy in
                CameraFocusExposureControl(
                    focusPoint: CGPoint(
                        x: proxy.size.width / 2,
                        y: proxy.size.height / 2
                    ),
                    minimumExposureBias: -2,
                    maximumExposureBias: 2,
                    selectedExposureBias: selectedExposureBias,
                    isExposureEnabled: true,
                    onSelectExposureBias: onSelectExposureBias,
                    onExposureInteractionChanged: { _ in }
                )
            }

            VStack {
                HStack {
                    Text("MOCK PREVIEW")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())

                    Spacer()
                }

                Spacer()
            }
            .padding(16)
        }
        .animation(.easeInOut(duration: 0.2), value: areAnnotationsVisible)
        .animation(.easeInOut(duration: 0.2), value: selectedZoomFactor)
    }
}

private struct CameraDebugGuide: View {

    var color = Color(
        red: 209.0 / 255.0,
        green: 213.0 / 255.0,
        blue: 220.0 / 255.0
    ).opacity(0.7)

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let oneThirdWidth = proxy.size.width / 3
                let oneThirdHeight = proxy.size.height / 3

                for index in 1...2 {
                    let x = oneThirdWidth * CGFloat(index)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))

                    let y = oneThirdHeight * CGFloat(index)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(color, lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Camera Debug") {
    NavigationStack {
        CameraDebugView()
    }
}
