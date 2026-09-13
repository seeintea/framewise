//
//  CameraZoomControls.swift
//  Framewise
//
//  Created by Codex on 2026/9/13.
//

import SwiftUI

struct CameraZoomControls: View {
    @Binding var selectedZoom: Double

    private let zoomOptions = [0.5, 1.0, 2.0]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(zoomOptions, id: \.self) { zoom in
                Button {
                    selectedZoom = zoom
                } label: {
                    Text(zoomLabel(for: zoom))
                        .font(.system(size: 14, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(
                            selectedZoom == zoom ? Color.yellow : .white
                        )
                        .frame(width: 36, height: 36)
                        .background {
                            if selectedZoom == zoom {
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
                .accessibilityLabel("相机缩放 \(zoomLabel(for: zoom))")
                .accessibilityAddTraits(
                    selectedZoom == zoom ? .isSelected : []
                )
            }
        }
    }

    private func zoomLabel(for zoom: Double) -> String {
        zoom == zoom.rounded() ? "\(Int(zoom))×" : "\(zoom.formatted())×"
    }
}
