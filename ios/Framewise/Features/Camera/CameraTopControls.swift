//
//  CameraTopControls.swift
//  Framewise
//
//  Created by Codex on 2026/9/13.
//

import SwiftUI

struct CameraTopControls: ToolbarContent {
    @Binding var isFlashEnabled: Bool
    @Binding var areAnnotationsVisible: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                isFlashEnabled.toggle()
            } label: {
                Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash")
            }
            .tint(isFlashEnabled ? .yellow : .white)
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
