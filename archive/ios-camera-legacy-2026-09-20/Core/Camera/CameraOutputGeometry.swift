//
//  CameraOutputGeometry.swift
//  Framewise legacy camera snapshot
//
//  Created by Codex on 2026/9/14.
//

import CoreGraphics

enum CameraOutputGeometry {
    nonisolated static func centeredCropRect(
        in extent: CGRect,
        targetAspectRatio: Double
    ) -> CGRect {
        guard extent.width > 0,
              extent.height > 0,
              targetAspectRatio > 0 else {
            return .null
        }

        let targetRatio = CGFloat(targetAspectRatio)
        let currentRatio = extent.width / extent.height
        let cropSize: CGSize

        if currentRatio > targetRatio {
            cropSize = CGSize(
                width: extent.height * targetRatio,
                height: extent.height
            )
        } else {
            cropSize = CGSize(
                width: extent.width,
                height: extent.width / targetRatio
            )
        }

        return CGRect(
            x: extent.midX - cropSize.width / 2,
            y: extent.midY - cropSize.height / 2,
            width: cropSize.width,
            height: cropSize.height
        )
    }

    nonisolated static func evenPixelSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: max(2, (size.width / 2).rounded(.down) * 2),
            height: max(2, (size.height / 2).rounded(.down) * 2)
        )
    }

    nonisolated static func normalizedRotationTransform(
        clockwiseRotationAngle: Double,
        sourceSize: CGSize
    ) -> (transform: CGAffineTransform, outputSize: CGSize) {
        let radians = CGFloat(
            normalizedQuarterTurns(clockwiseRotationAngle)
        ) * .pi / 2
        let rotation = CGAffineTransform(rotationAngle: radians)
        let rotatedBounds = CGRect(origin: .zero, size: sourceSize)
            .applying(rotation)
        let transform = rotation.concatenating(
            CGAffineTransform(
                translationX: -rotatedBounds.minX,
                y: -rotatedBounds.minY
            )
        )

        return (
            transform,
            CGSize(
                width: abs(rotatedBounds.width),
                height: abs(rotatedBounds.height)
            )
        )
    }

    nonisolated static func normalizedQuarterTurns(
        _ angle: Double
    ) -> Int {
        let roundedTurns = Int((angle / 90).rounded())
        return ((roundedTurns % 4) + 4) % 4
    }
}
