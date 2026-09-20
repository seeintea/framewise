//
//  CameraExposureControl.swift
//  Framewise legacy camera snapshot
//
//  Created by Codex on 2026/9/14.
//

import SwiftUI

struct CameraExposureControl: View {
    static let layoutSize = CGSize(width: 36, height: 96)

    let minimumBias: Double
    let maximumBias: Double
    let selectedBias: Double
    let isEnabled: Bool
    let onSelectBias: (Double) -> Void
    let onInteractionChanged: (Bool) -> Void

    @State private var biasAtDragStart: Double?

    private let dragTravelMultiplier = 1.75

    var body: some View {
        GeometryReader { proxy in
            let progress = progress(for: selectedBias)
            let travel = max(proxy.size.height - 12, 0)

            ZStack {
                Capsule()
                    .fill(.yellow.opacity(0.55))
                    .frame(width: 1)

                Image(systemName: "sun.max.fill")
                    .frame(width: 12, height: 12)
                    .offset(y: travel * (0.5 - progress))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if biasAtDragStart == nil {
                            biasAtDragStart = selectedBias
                            onInteractionChanged(true)
                        }

                        selectBias(
                            from: biasAtDragStart ?? selectedBias,
                            translationY: value.translation.height,
                            trackHeight: proxy.size.height
                        )
                    }
                    .onEnded { _ in
                        guard biasAtDragStart != nil else {
                            return
                        }

                        biasAtDragStart = nil
                        onInteractionChanged(false)
                    }
            )
        }
        .frame(width: Self.layoutSize.width, height: Self.layoutSize.height)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.yellow)
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("曝光")
        .accessibilityValue("\(selectedBias, specifier: "%+.1f") EV")
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? 0.1 : -0.1
            onInteractionChanged(true)
            onSelectBias(clampedAndRounded(selectedBias + delta))
            onInteractionChanged(false)
        }
    }

    private func progress(for bias: Double) -> CGFloat {
        guard maximumBias > minimumBias else {
            return 0.5
        }

        return CGFloat((bias - minimumBias) / (maximumBias - minimumBias))
    }

    private func selectBias(
        from startingBias: Double,
        translationY: CGFloat,
        trackHeight: CGFloat
    ) {
        guard trackHeight > 0, maximumBias > minimumBias else {
            return
        }

        let range = maximumBias - minimumBias
        let travel = Double(trackHeight) * dragTravelMultiplier
        let bias = startingBias - Double(translationY) * range / travel
        onSelectBias(clampedAndRounded(bias))
    }

    private func clampedAndRounded(_ bias: Double) -> Double {
        let clampedBias = min(max(bias, minimumBias), maximumBias)
        return (clampedBias * 10).rounded() / 10
    }
}
