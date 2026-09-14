//
//  CameraZoomControls.swift
//  Framewise
//
//  Created by Codex on 2026/9/13.
//

import SwiftUI

struct CameraZoomControls: View {
    let zoomFactors: [Double]
    let selectedZoomFactor: Double
    let isEnabled: Bool
    let onSelectZoomFactor: (Double) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(zoomFactors, id: \.self) { zoom in
                Button {
                    onSelectZoomFactor(zoom)
                } label: {
                    Text(zoomLabel(for: zoom))
                        .font(.system(size: 14, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(
                            isSelected(zoom) ? Color.yellow : .white
                        )
                        .frame(width: 36, height: 36)
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
        let value = zoom.formatted(
            .number.precision(.fractionLength(0...1))
        )
        return "\(value)×"
    }

    private func isSelected(_ zoom: Double) -> Bool {
        abs(selectedZoomFactor - zoom) < 0.01
    }
}
