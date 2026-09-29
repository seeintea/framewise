//
//  CameraShutterFeedback.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import SwiftUI

struct CameraShutterFeedback: View {
    let captureID: UUID
    let isLivePhoto: Bool
    @Binding var isActive: Bool

    var body: some View {
        Color.black
            .keyframeAnimator(initialValue: 0.0, trigger: captureID) {
                content, opacity in
                content.opacity(opacity)
                    .task(id: opacity > 0) { @MainActor in
                        isActive = opacity > 0
                    }
            } keyframes: { _ in
                // Restart clear on each shot, including overlapping captures.
                // Delay + darken + hold + reveal totals 450 ms / 760 ms.
                MoveKeyframe(0.0)
                LinearKeyframe(
                    0.0,
                    duration: isLivePhoto ? 0.13 : 0.05
                )
                CubicKeyframe(
                    1.0,
                    duration: isLivePhoto ? 0.16 : 0.08,
                    startVelocity: 0,
                    endVelocity: 0
                )
                LinearKeyframe(
                    1.0,
                    duration: isLivePhoto ? 0.09 : 0.07
                )
                CubicKeyframe(
                    0.0,
                    duration: isLivePhoto ? 0.38 : 0.25,
                    startVelocity: 0,
                    endVelocity: 0
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onDisappear { isActive = false }
    }
}
