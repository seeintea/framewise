//
//  CameraToolbarControls.swift
//  Framewise legacy camera snapshot
//
//  Created by yukkuri on 2026/9/16.
//

import SwiftUI

struct CameraToolbarControls: ToolbarContent {
    let isLivePhotoEnabled: Bool
    let isLivePhotoControlEnabled: Bool
    let onToggleLivePhoto: () -> Void
    let isFlashEnabled: Bool
    let isFlashAvailable: Bool
    let onToggleFlash: () -> Void
    @Binding var areAnnotationsVisible: Bool
    let controlRotation: Angle

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button(action: onToggleFlash) {
                    Image(
                        systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash"
                    ).resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .rotationEffect(controlRotation)
                }
                .tint(isFlashEnabled ? .yellow : .white)
                .disabled(!isFlashAvailable)
                .accessibilityLabel(isFlashEnabled ? "关闭闪光灯" : "打开闪光灯")

                Button(action: onToggleLivePhoto) {
                    Image(
                        systemName: isLivePhotoEnabled
                            ? "livephoto"
                            : "livephoto.slash"
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .rotationEffect(controlRotation)
                }
                .tint(.white)
                .disabled(!isLivePhotoControlEnabled)
                .accessibilityLabel(
                    isLivePhotoEnabled ? "关闭实况照片" : "打开实况照片"
                )

                Button {
                    areAnnotationsVisible.toggle()
                } label: {
                    Image(systemName: "questionmark.circle").resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .rotationEffect(controlRotation)
                }
                .tint(.white)
                .accessibilityLabel(
                    areAnnotationsVisible ? "隐藏构图提示" : "显示构图提示"
                )

                Button(action: {}) {
                    VStack(spacing: -8) {
                        Image(systemName: "ellipsis").resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Image(systemName: "ellipsis").resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                    .rotationEffect(controlRotation)
                }
                .tint(.white)
                .accessibilityLabel(
                    "打开更多设置"
                )
            }
            .padding(.horizontal, 12)
        }
    }
}
