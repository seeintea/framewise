//
//  CameraTopBarControls.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation
import SwiftUI

struct CameraTopBarControls: ToolbarContent {
    let flashMode: AVCaptureDevice.FlashMode
    let availableFlashModes: [AVCaptureDevice.FlashMode]
    let onToggleFlash: () -> Void
    let isLivePhotoEnabled: Bool
    let onToggleLivePhoto: () -> Void
    let areAnnotationsVisible: Bool
    let onToggleAnnotations: () -> Void
    let onMore: () -> Void
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
                    }
                    .tint(.white)
                    .accessibilityLabel(Text(.cameraMoreSettings))
                }
            }
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

    private func flashTitle(for mode: AVCaptureDevice.FlashMode) -> LocalizedStringKey {
        switch mode {
        case .off: "camera.flash.off"
        case .auto: "camera.flash.auto"
        case .on: "camera.flash.on"
        @unknown default: "camera.flash.off"
        }
    }
}
