//
//  CameraTopBarControls.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import SwiftUI

struct CameraTopBarControls: ToolbarContent {
    let isFlashEnabled: Bool
    let onToggleFlash: () -> Void
    let isLivePhotoEnabled: Bool
    let onToggleLivePhoto: () -> Void
    let areAnnotationsVisible: Bool
    let onToggleAnnotations: () -> Void
    let onMore: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button(action: onToggleFlash) {
                    Image(
                        systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash"
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                }
                .tint(isFlashEnabled ? .yellow : .white)
                .accessibilityLabel(
                    isFlashEnabled
                        ? Text(.cameraFlashOff) : Text(.cameraFlashOn)
                )

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
            .padding(.horizontal, 12)
        }
    }
}
