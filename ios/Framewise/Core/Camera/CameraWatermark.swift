//
//  CameraWatermark.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/27.
//

import CoreImage
import UIKit

/// A small raster badge shared by stills and movies, laid out in final output coordinates.
nonisolated struct CameraWatermark {
    enum RenderingError: Error { case missingLogo, invalidBadge }

    private let logo: UIImage

    init() throws {
        guard let logo = UIImage(named: "WatermarkLogo") else {
            throw RenderingError.missingLogo
        }
        self.logo = logo
    }

    private func badge(for size: CGSize) -> (image: UIImage, frame: CGRect) {
        let unit = min(size.width, size.height)
        let margin = unit * 0.025
        let padding = unit * 0.012
        let logoSide = unit * 0.045
        let gap = unit * 0.01
        // This fixed brand wordmark intentionally stays Chinese in every locale.
        let title = "蒙版相机" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: unit * 0.028, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
        let textSize = title.size(withAttributes: attributes)
        let badgeSize = CGSize(
            width: ceil(padding * 2 + logoSide + gap + textSize.width),
            height: ceil(padding * 2 + max(logoSide, textSize.height))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: badgeSize, format: format).image { _ in
            UIColor.black.withAlphaComponent(0.35).setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: badgeSize),
                cornerRadius: padding
            ).fill()
            logo.draw(in: CGRect(
                x: padding, y: (badgeSize.height - logoSide) / 2,
                width: logoSide, height: logoSide
            ))
            title.draw(at: CGPoint(
                x: padding + logoSide + gap,
                y: (badgeSize.height - textSize.height) / 2
            ), withAttributes: attributes)
        }
        return (image, CGRect(
            x: size.width - margin - badgeSize.width,
            y: size.height - margin - badgeSize.height,
            width: badgeSize.width, height: badgeSize.height
        ))
    }

    func draw(in size: CGSize) {
        let badge = badge(for: size)
        badge.image.draw(in: badge.frame)
    }

    func coreImageOverlay(for size: CGSize) throws -> CIImage {
        let badge = badge(for: size)
        guard let pixels = badge.image.cgImage else { throw RenderingError.invalidBadge }
        return CIImage(cgImage: pixels).transformed(by: CGAffineTransform(
            translationX: badge.frame.minX,
            y: size.height - badge.frame.maxY
        ))
    }
}
