//
//  CameraCaptureControls.swift
//  Framewise
//
//  Created by Codex on 2026/9/13.
//

import SwiftUI

struct CameraCaptureControls: View {
    let isFrontFacing: Bool
    let isCaptureEnabled: Bool
    let canSwitchCamera: Bool
    let onCapture: () -> Void
    let onSwitchCamera: () -> Void

    var body: some View {
        actionControls
    }

    private var actionControls: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 21, weight: .light))
                    .foregroundStyle(Color(red: 216 / 255, green: 216 / 255, blue: 220 / 255))
                    .frame(width: 52, height: 52)
                    .background(
                        Color(red: 58.0 / 255.0, green: 58.0 / 255.0, blue: 62.0 / 255.0)
                    )
                    .clipShape(Circle())
                    .padding(3)
                    .background(
                        Color(red: 41.0 / 255.0, green: 41.0 / 255.0, blue: 44.0 / 255.0)
                    )
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.16), lineWidth: 0.5)
                    }
            }
            .buttonStyle(CameraControlButtonStyle())
            .disabled(true)
            .opacity(0.45)
            .accessibilityLabel("打开相册")

            Spacer()

            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.58))
                        .frame(width: 84, height: 84)

                    Circle()
                        .fill(Color(red: 17.0 / 255.0, green: 17.0 / 255.0, blue: 19.0 / 255.0))
                        .frame(width: 76, height: 76)

                    Circle()
                        .fill(.white)
                        .frame(width: 68, height: 68)
                }
            }
            .buttonStyle(CameraControlButtonStyle())
            .disabled(!isCaptureEnabled)
            .opacity(isCaptureEnabled ? 1 : 0.45)
            .accessibilityLabel("拍照")

            Spacer()

            Button(action: onSwitchCamera) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 27, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(
                        Color(red: 41.0 / 255.0, green: 41.0 / 255.0, blue: 44.0 / 255.0)
                    )
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.09), lineWidth: 0.5)
                    }
                    .rotationEffect(isFrontFacing ? .degrees(180) : .zero)
            }
            .buttonStyle(CameraControlButtonStyle())
            .disabled(!canSwitchCamera)
            .opacity(canSwitchCamera ? 1 : 0.45)
            .accessibilityLabel("切换前后摄像头")
        }
        .frame(height: 90)
    }

}
