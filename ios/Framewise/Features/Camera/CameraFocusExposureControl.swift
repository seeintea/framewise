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
    let onExposureInteractionChanged: (Bool) -> Void

    private let indicatorSize: CGFloat = 72
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
                        onSelectBias: onSelectExposureBias,
                        onInteractionChanged: onExposureInteractionChanged
                    )
                    .position(
                        x: exposureControlX(in: proxy.size.width),
                        y: focusPoint.y
                    )
                }
            }
        }
        .clipped()
    }

    private var exposureControlOffset: CGFloat {
        indicatorSize / 2
            + spacing
            + CameraExposureControl.layoutSize.width / 2
    }

    private func exposureControlX(in availableWidth: CGFloat) -> CGFloat {
        let rightX = focusPoint.x + exposureControlOffset
        let maximumX = availableWidth
            - edgePadding
            - CameraExposureControl.layoutSize.width / 2

        if rightX <= maximumX {
            return rightX
        }

        return focusPoint.x - exposureControlOffset
    }
}
