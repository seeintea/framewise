//
//  CameraBottomControls.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/16.
//

import SwiftUI

struct CameraBottomControls: View {
    let isCaptureEnabled: Bool
    let canSwitchCamera: Bool
    let onCapture: () -> Void
    let onSwitchCamera: () -> Void
    let controlRotation: Angle

    var body: some View {
        actionControls
    }

    private var actionControls: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 21, weight: .light))
                    .rotationEffect(controlRotation)
                    .foregroundStyle(
                        Color(red: 216 / 255, green: 216 / 255, blue: 220 / 255)
                    )
                    .frame(width: 52, height: 52)
                    .background(
                        Color(
                            red: 58.0 / 255.0,
                            green: 58.0 / 255.0,
                            blue: 62.0 / 255.0
                        )
                    )
                    .clipShape(Circle())
                    .padding(3)
                    .background(
                        Color(
                            red: 41.0 / 255.0,
                            green: 41.0 / 255.0,
                            blue: 44.0 / 255.0
                        )
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
                        .fill(
                            Color(
                                red: 17.0 / 255.0,
                                green: 17.0 / 255.0,
                                blue: 19.0 / 255.0
                            )
                        )
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
                Image(.cameraRotate)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(controlRotation)
                    .foregroundStyle(.white)
                    .frame(width: 27, height: 27)
                    .frame(width: 58, height: 58)
                    .background(
                        Color(
                            red: 41.0 / 255.0,
                            green: 41.0 / 255.0,
                            blue: 44.0 / 255.0
                        )
                    )
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.09), lineWidth: 0.5)
                    }
            }
            .buttonStyle(CameraControlButtonStyle())
            .disabled(!canSwitchCamera)
            .opacity(canSwitchCamera ? 1 : 0.45)
            .accessibilityLabel("切换前后摄像头")
        }
        .frame(height: 90)
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
