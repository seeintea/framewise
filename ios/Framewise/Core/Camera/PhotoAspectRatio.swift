//
//  PhotoAspectRatio.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import UIKit

enum PhotoAspectRatio: String, CaseIterable, Identifiable, Sendable {
    case square = "1:1"
    case standard = "3:4"
    case standardLandscape = "4:3"
    case tall = "9:16"
    case tallLandscape = "16:9"

    var id: String { rawValue }

    nonisolated var dimensions: (width: Int, height: Int) {
        switch self {
        case .square: (1, 1)
        case .standard, .standardLandscape: (3, 4)
        case .tall, .tallLandscape: (9, 16)
        }
    }

    nonisolated var isLandscapeOutput: Bool {
        self == .standardLandscape || self == .tallLandscape
    }

    nonisolated var value: CGFloat {
        CGFloat(dimensions.width) / CGFloat(dimensions.height)
    }

    /// Normalizes orientation, crops in portrait coordinates, and applies the final
    /// quarter turn in one render. Callers supply -1, 0, or 1 quarter turns.
    nonisolated func renderedImage(
        from data: Data,
        quarterTurns: Int,
        drawOverlay: ((CGSize) -> Void)? = nil
    ) -> UIImage? {
        guard let image = UIImage(data: data), let cgImage = image.cgImage
        else {
            return nil
        }
        let isQuarterTurn: Bool = {
            switch image.imageOrientation {
            case .left, .right, .leftMirrored, .rightMirrored: true
            default: false
            }
        }()
        let sourceWidth = isQuarterTurn ? cgImage.height : cgImage.width
        let sourceHeight = isQuarterTurn ? cgImage.width : cgImage.height
        let units = min(
            sourceWidth / dimensions.width,
            sourceHeight / dimensions.height
        )
        guard units > 0 else { return nil }
        let cropWidth = units * dimensions.width
        let cropHeight = units * dimensions.height
        let outputSize = CGSize(
            width: quarterTurns == 0 ? cropWidth : cropHeight,
            height: quarterTurns == 0 ? cropHeight : cropWidth
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: outputSize,
            format: format
        )
        return renderer.image { context in
            context.cgContext.saveGState()
            // Transform the portrait crop into the final canvas before drawing
            // the source. UIImage.draw handles the source orientation and mirror.
            if quarterTurns < 0 {
                context.cgContext.translateBy(x: 0, y: outputSize.height)
            } else if quarterTurns > 0 {
                context.cgContext.translateBy(x: outputSize.width, y: 0)
            }
            context.cgContext.rotate(by: CGFloat(quarterTurns) * .pi / 2)
            image.draw(
                in: CGRect(
                    x: CGFloat(cropWidth - sourceWidth) / 2,
                    y: CGFloat(cropHeight - sourceHeight) / 2,
                    width: CGFloat(sourceWidth),
                    height: CGFloat(sourceHeight)
                )
            )
            context.cgContext.restoreGState()
            // Keep the watermark upright, independent of source orientation or mirroring.
            drawOverlay?(outputSize)
        }
    }
}
