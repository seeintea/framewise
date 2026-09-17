//
//  CameraFocusExposureControl.swift
//  Framewise
//
//  Created by Codex on 2026/9/17.
//

import SwiftUI

struct CameraFocusExposureControl: View {
    let focusPoint: CGPoint
    let minimumExposureBias: Double
    let maximumExposureBias: Double
    let selectedExposureBias: Double
    let isExposureEnabled: Bool
    let onSelectExposureBias: (Double) -> Void

    private let indicatorSize: CGFloat = 72
    private let controlSize = CameraExposureControl.layoutSize
    private let spacing: CGFloat = 10
    private let edgePadding: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CameraFocusIndicator(size: indicatorSize)
                    .position(focusPoint)

                if maximumExposureBias > minimumExposureBias {
                    CameraExposureControl(
                        minimumBias: minimumExposureBias,
                        maximumBias: maximumExposureBias,
                        selectedBias: selectedExposureBias,
                        isEnabled: isExposureEnabled,
                        onSelectBias: onSelectExposureBias
                    )
                    .position(
                        x: exposureControlX(in: proxy.size.width),
                        y: exposureControlY(in: proxy.size.height)
                    )
                }
            }
        }
    }

    private func exposureControlX(in availableWidth: CGFloat) -> CGFloat {
        let offset = indicatorSize / 2 + spacing + controlSize.width / 2
        let rightX = focusPoint.x + offset
        let maximumX = availableWidth - edgePadding - controlSize.width / 2

        if rightX <= maximumX {
            return rightX
        }

        let minimumX = edgePadding + controlSize.width / 2
        return max(focusPoint.x - offset, minimumX)
    }

    private func exposureControlY(in availableHeight: CGFloat) -> CGFloat {
        let minimumY = edgePadding + controlSize.height / 2
        let maximumY = availableHeight - edgePadding - controlSize.height / 2
        return min(max(focusPoint.y, minimumY), maximumY)
    }
}
