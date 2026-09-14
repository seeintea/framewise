//
//  CameraExposureControl.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

import SwiftUI

struct CameraExposureControl: View {
    let minimumBias: Double
    let maximumBias: Double
    let selectedBias: Double
    let isEnabled: Bool
    let onSelectBias: (Double) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.min")

            Slider(
                value: Binding(
                    get: { selectedBias },
                    set: onSelectBias
                ),
                in: minimumBias...maximumBias,
                step: 0.1
            )
            .tint(.yellow)

            Image(systemName: "sun.max")

            Text("\(selectedBias, specifier: "%+.1f") EV")
                .font(.caption.monospacedDigit())
                .frame(width: 58, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: Capsule())
        .disabled(!isEnabled)
    }
}
