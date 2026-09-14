//
//  CameraTopControls.swift
//  Framewise
//
//  Created by Codex on 2026/9/13.
//

import SwiftUI

struct CameraTopControls: ToolbarContent {
    let isLivePhotoEnabled: Bool
    let isLivePhotoControlEnabled: Bool
    let onToggleLivePhoto: () -> Void
    let isFlashEnabled: Bool
    let isFlashAvailable: Bool
    let onToggleFlash: () -> Void
    @Binding var areAnnotationsVisible: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: onToggleLivePhoto) {
                Image(
                    systemName: isLivePhotoEnabled
                        ? "livephoto"
                        : "livephoto.slash"
                )
            }
            .tint(isLivePhotoEnabled ? .yellow : .white)
            .disabled(!isLivePhotoControlEnabled)
            .accessibilityLabel(
                isLivePhotoEnabled ? "关闭实况照片" : "打开实况照片"
            )

            Button(action: onToggleFlash) {
                Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash")
            }
            .tint(isFlashEnabled ? .yellow : .white)
            .disabled(!isFlashAvailable)
            .accessibilityLabel(isFlashEnabled ? "关闭闪光灯" : "打开闪光灯")

            Button {
                areAnnotationsVisible.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .tint(areAnnotationsVisible ? .yellow : .white)
            .accessibilityLabel(
                areAnnotationsVisible ? "隐藏构图提示" : "显示构图提示"
            )
        }
    }
}

struct CameraControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
