//
//  CameraInterruptionNotice.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import SwiftUI

struct CameraInterruptionNotice: View {
    let canResume: Bool
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.title2)
            Text(.cameraSessionInterruptedTitle)
                .font(.headline)
            Text(.cameraSessionInterruptedMessage)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            if canResume {
                Button(.cameraAccessActionRetry) { onResume() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }
}
