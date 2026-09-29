//
//  CameraLivePhotoNotice.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import SwiftUI

struct CameraLivePhotoNotice: View {
    let reason: CameraEngine.LivePhotoUnavailableReason
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "livephoto.slash")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.footnote)
            Spacer(minLength: 4)
            if reason == .microphoneDenied || reason == .microphoneRestricted {
                Button(.cameraAccessActionOpenSettings) {
                    Task { await Permissions.openSettings() }
                }
                .font(.footnote.weight(.semibold))
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(Text(.cameraErrorOk))
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var message: LocalizedStringResource {
        switch reason {
        case .unsupported: .cameraLiveFallbackUnsupported
        case .microphoneDenied: .cameraLiveFallbackMicrophoneDenied
        case .microphoneRestricted: .cameraLiveFallbackMicrophoneRestricted
        case .microphoneUnavailable: .cameraLiveFallbackMicrophoneUnavailable
        }
    }

}
