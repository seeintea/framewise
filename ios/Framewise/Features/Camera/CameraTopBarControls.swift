//
//  CameraTopBarControls.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation
import SwiftUI

struct CameraTopBarControls: ToolbarContent {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let flashMode: AVCaptureDevice.FlashMode
    let availableFlashModes: [AVCaptureDevice.FlashMode]
    let onToggleFlash: () -> Void
    let isLivePhotoEnabled: Bool
    let onToggleLivePhoto: () -> Void
    let areAnnotationsVisible: Bool
    let onToggleAnnotations: () -> Void
    let onMore: () -> Void
    var controlRotation = Angle.zero
    var isCameraReady = true
    var showsMore = true

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button(action: onToggleFlash) {
                    Image(systemName: flashSymbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .rotationEffect(controlRotation)
                }
                .tint(flashMode == .off ? .white : .yellow)
                .disabled(!isCameraReady || availableFlashModes.count < 2)
                .accessibilityLabel(flashTitle(for: flashMode))

                Button(action: onToggleLivePhoto) {
                    Image(
                        systemName: isLivePhotoEnabled
                            ? "livephoto" : "livephoto.slash"
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .rotationEffect(controlRotation)
                }
                .tint(.white)
                .disabled(!isCameraReady)
                .accessibilityLabel(
                    isLivePhotoEnabled
                        ? Text(.cameraLiveDisable) : Text(.cameraLiveEnable)
                )

                Button(action: onToggleAnnotations) {
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .rotationEffect(controlRotation)
                }
                .tint(.white)
                .accessibilityLabel(
                    areAnnotationsVisible
                        ? Text(.cameraAnnotationsHide)
                        : Text(.cameraAnnotationsShow)
                )

                if showsMore {
                    Button(action: onMore) {
                        VStack(spacing: -8) {
                            Image(systemName: "ellipsis")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Image(systemName: "ellipsis")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                        .rotationEffect(controlRotation)
                    }
                    .tint(.white)
                    .accessibilityLabel(Text(.cameraMoreSettings))
                }
            }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value: controlRotation
            )
            .padding(.horizontal, 12)
        }
    }

    private var flashSymbol: String {
        switch flashMode {
        case .off: "bolt.slash"
        case .auto: "bolt"
        case .on: "bolt.fill"
        @unknown default: "bolt.slash"
        }
    }

    private func flashTitle(for mode: AVCaptureDevice.FlashMode) -> LocalizedStringResource {
        switch mode {
        case .off: .cameraFlashOff
        case .auto: .cameraFlashAuto
        case .on: .cameraFlashOn
        @unknown default: .cameraFlashOff
        }
    }
}
