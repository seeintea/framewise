//
//  CameraZoomControls.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import SwiftUI

struct CameraZoomControls: View {
    let zoomFactors: [Double]
    let selectedZoomFactor: Double
    let isEnabled: Bool
    let onSelectZoomFactor: (Double) -> Void
    let controlRotation: Angle

    var body: some View {
        HStack(spacing: 6) {
            ForEach(zoomFactors, id: \.self) { zoom in
                Button {
                    onSelectZoomFactor(zoom)
                } label: {
                    Text(zoomLabel(for: zoom))
                        .font(.system(size: 13, weight: .light))
                        .monospacedDigit()
                        .rotationEffect(controlRotation)
                        .foregroundStyle(isSelected(zoom) ? .yellow : .white)
                        .frame(width: 38, height: 38)
                        .background {
                            if isSelected(zoom) {
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
                .accessibilityLabel(
                    Text(
                        .cameraZoomAccessibilityLabel(
                            zoom: zoomLabel(for: zoom)
                        )
                    )
                )
                .accessibilityAddTraits(isSelected(zoom) ? .isSelected : [])
            }
        }
    }

    private func zoomLabel(for zoom: Double) -> String {
        let displayedZoom =
            isSelected(zoom) && !isPresetZoomSelected
            ? selectedZoomFactor : zoom
        let value = displayedZoom.formatted(
            .number.precision(.fractionLength(0...1))
        )
        return "\(value)×"
    }

    private func isSelected(_ zoom: Double) -> Bool {
        zoomFactors.firstIndex(of: zoom) == selectedZoomIndex
    }

    private var isPresetZoomSelected: Bool {
        zoomFactors.contains { abs(selectedZoomFactor - $0) < 0.01 }
    }

    private var selectedZoomIndex: Int? {
        guard !zoomFactors.isEmpty else { return nil }
        if let exactIndex = zoomFactors.firstIndex(where: {
            abs(selectedZoomFactor - $0) < 0.01
        }) {
            return exactIndex
        }
        if let nextIndex = zoomFactors.firstIndex(where: {
            selectedZoomFactor < $0
        }) {
            return max(nextIndex - 1, 0)
        }
        return zoomFactors.count - 1
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
