//
//  CameraFocusExposureControl.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
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
    let controlRotation: Angle

    private let indicatorSize: CGFloat = 72
    private let spacing: CGFloat = 5
    private let edgePadding: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let exposurePosition = exposureControlPosition(in: geometry.size)

            ZStack {
                CameraFocusIndicator(size: indicatorSize)
                    .rotationEffect(controlRotation)
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
                    .rotationEffect(controlRotation)
                    .position(exposurePosition)
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

    private func exposureControlPosition(in availableSize: CGSize) -> CGPoint {
        let radians = controlRotation.radians
        let direction = CGVector(
            dx: CGFloat(cos(radians)),
            dy: CGFloat(sin(radians))
        )
        let preferredPosition = CGPoint(
            x: focusPoint.x + direction.dx * exposureControlOffset,
            y: focusPoint.y + direction.dy * exposureControlOffset
        )

        if controlFits(
            at: preferredPosition,
            along: direction,
            in: availableSize
        ) {
            return preferredPosition
        }

        return CGPoint(
            x: focusPoint.x - direction.dx * exposureControlOffset,
            y: focusPoint.y - direction.dy * exposureControlOffset
        )
    }

    private func controlFits(
        at position: CGPoint,
        along direction: CGVector,
        in availableSize: CGSize
    ) -> Bool {
        let radians = controlRotation.radians
        let cosine = CGFloat(abs(cos(radians)))
        let sine = CGFloat(abs(sin(radians)))
        let size = CameraExposureControl.layoutSize
        let rotatedWidth = size.width * cosine + size.height * sine
        let rotatedHeight = size.width * sine + size.height * cosine

        if abs(direction.dx) >= abs(direction.dy) {
            if direction.dx >= 0 {
                return position.x + rotatedWidth / 2
                    <= availableSize.width - edgePadding
            }
            return position.x - rotatedWidth / 2 >= edgePadding
        }

        if direction.dy >= 0 {
            return position.y + rotatedHeight / 2
                <= availableSize.height - edgePadding
        }
        return position.y - rotatedHeight / 2 >= edgePadding
    }
}
