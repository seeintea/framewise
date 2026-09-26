//
//  CameraZoomControls.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import SwiftUI

struct CameraZoomControls: View {
    let zoomOptions: [CameraEngine.ZoomOption]
    let selectedZoomFactor: CGFloat
    let isEnabled: Bool
    let onSelectZoomFactor: (CGFloat) -> Void
    let controlRotation: Angle
    var isFrontCamera = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(zoomOptions, id: \.factor) { option in
                Button {
                    onSelectZoomFactor(option.factor)
                } label: {
                    Text(verbatim: zoomLabel(for: option))
                        .font(.system(size: 13, weight: .light))
                        .monospacedDigit()
                        .rotationEffect(controlRotation)
                        .foregroundStyle(isSelected(option) ? .yellow : .white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .background {
                            if isSelected(option) {
                                Circle()
                                    .fill(
                                        Color(
                                            red: 74.0 / 255.0,
                                            green: 72.0 / 255.0,
                                            blue: 77.0 / 255.0
                                        )
                                        .opacity(0.96)
                                    )
                            }
                        }
                }
                .buttonStyle(CameraZoomButtonStyle())
                .disabled(!isEnabled)
                .accessibilityLabel(accessibilityLabel(for: option))
                .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
            }
        }
    }

    private func zoomLabel(for option: CameraEngine.ZoomOption) -> String {
        guard !isFrontCamera else { return option.label }
        let displayedZoom =
            isSelected(option) && !isPresetZoomSelected
            ? Double(selectedZoomFactor / oneXFactor) : nil
        guard let displayedZoom else { return option.label }
        let value = displayedZoom.formatted(
            .number.precision(.fractionLength(0...1))
        )
        return "\(value)×"
    }

    private func accessibilityLabel(for option: CameraEngine.ZoomOption) -> Text {
        if isFrontCamera {
            Text(verbatim: option.label)
        } else {
            Text(.cameraZoomAccessibilityLabel(zoom: zoomLabel(for: option)))
        }
    }

    private var oneXFactor: CGFloat {
        zoomOptions.first { $0.label == "1×" }?.factor ?? 1
    }

    private func isSelected(_ option: CameraEngine.ZoomOption) -> Bool {
        zoomOptions.firstIndex(of: option) == selectedZoomIndex
    }

    private var isPresetZoomSelected: Bool {
        zoomOptions.contains { abs(selectedZoomFactor - $0.factor) < 0.01 }
    }

    private var selectedZoomIndex: Int? {
        guard !zoomOptions.isEmpty else { return nil }
        if let exactIndex = zoomOptions.firstIndex(where: {
            abs(selectedZoomFactor - $0.factor) < 0.01
        }) {
            return exactIndex
        }
        if let nextIndex = zoomOptions.firstIndex(where: {
            selectedZoomFactor < $0.factor
        }) {
            return max(nextIndex - 1, 0)
        }
        return zoomOptions.count - 1
    }
}

private struct CameraZoomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
