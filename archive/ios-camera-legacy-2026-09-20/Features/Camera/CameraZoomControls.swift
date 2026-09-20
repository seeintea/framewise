//
//  CameraZoomControls.swift
//  Framewise legacy camera snapshot
//
//  Created by Codex on 2026/9/13.
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
                        .foregroundStyle(
                            isSelected(zoom) ? Color.yellow : .white
                        )
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
                .buttonStyle(CameraControlButtonStyle())
                .disabled(!isEnabled)
                .accessibilityLabel("相机缩放 \(zoomLabel(for: zoom))")
                .accessibilityAddTraits(
                    isSelected(zoom) ? .isSelected : []
                )
            }
        }
    }

    private func zoomLabel(for zoom: Double) -> String {
        if isSelected(zoom), !isPresetZoomSelected {
            let value = selectedZoomFactor.formatted(
                .number.precision(.fractionLength(0...1))
            )
            return "\(value)×"
        }

        let value = zoom.formatted(
            .number.precision(.fractionLength(0...1))
        )
        return "\(value)×"
    }

    private func isSelected(_ zoom: Double) -> Bool {
        guard let zoomIndex = zoomFactors.firstIndex(of: zoom) else {
            return false
        }

        return zoomIndex == selectedZoomIndex
    }

    private var isPresetZoomSelected: Bool {
        zoomFactors.contains {
            abs(selectedZoomFactor - $0) < 0.01
        }
    }

    private var selectedZoomIndex: Int? {
        guard !zoomFactors.isEmpty else {
            return nil
        }

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

#Preview("Camera Debug") {
    NavigationStack {
        CameraDebugView()
    }
}
