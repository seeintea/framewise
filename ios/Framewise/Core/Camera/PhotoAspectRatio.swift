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

    /// Renders an upright pixel matrix with an exact integer aspect ratio.
    nonisolated func croppedImage(from data: Data) -> UIImage? {
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
        let outputWidth = units * dimensions.width
        let outputHeight = units * dimensions.height
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputWidth, height: outputHeight),
            format: format
        )
        return renderer.image { _ in
            image.draw(
                in: CGRect(
                    x: CGFloat(outputWidth - sourceWidth) / 2,
                    y: CGFloat(outputHeight - sourceHeight) / 2,
                    width: CGFloat(sourceWidth),
                    height: CGFloat(sourceHeight)
                )
            )
        }
    }
}
