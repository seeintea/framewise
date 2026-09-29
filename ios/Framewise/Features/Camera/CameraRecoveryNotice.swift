//
//  CameraRecoveryNotice.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import SwiftUI

struct CameraRecoveryNotice: View {
    var body: some View {
        ProgressView {
            Text(.cameraSessionRecovering)
        }
        .tint(.white)
        .foregroundStyle(.white)
        .padding(24)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }
}
