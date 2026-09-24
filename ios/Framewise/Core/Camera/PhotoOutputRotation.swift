//
//  PhotoOutputRotation.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import UIKit

enum PhotoOutputRotation {
    /// Rotates the completed portrait crop; capture and crop geometry stay unchanged.
    nonisolated static func applied(to image: UIImage, quarterTurns: Int)
        -> UIImage
    {
        guard quarterTurns != 0 else { return image }

        let outputSize = CGSize(
            width: image.size.height,
            height: image.size.width
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)

        return renderer.image { context in
            if quarterTurns < 0 {
                context.cgContext.translateBy(x: 0, y: outputSize.height)
            } else {
                context.cgContext.translateBy(x: outputSize.width, y: 0)
            }
            context.cgContext.rotate(by: CGFloat(quarterTurns) * .pi / 2)
            image.draw(at: .zero)
        }
    }
}
