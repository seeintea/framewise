//
//  PhotoProcessor.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import ImageIO
import UIKit

/// Encodes the final pixels once, retaining the source camera and Live Photo metadata.
actor PhotoProcessor {
    static let shared = PhotoProcessor()

    enum ProcessingError: Error { case invalidPhoto }

    // Serialize full-resolution still renders to bound memory use during repeated shots.
    // A separate actor lets movie exports progress concurrently without blocking the UI.
    func process(
        _ data: Data,
        ratio: PhotoAspectRatio,
        quarterTurns: Int,
        recordStage: @Sendable (String) -> Void,
        onProcessed: @escaping @MainActor @Sendable (UIImage) -> Void
    ) async throws -> Data {
        try Task.checkCancellation()
        recordStage("photoProcessingStarted")
        let output: (data: Data, thumbnail: UIImage?) = try autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let sourceType = CGImageSourceGetType(source),
                let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                    as? [CFString: Any]
            else { throw ProcessingError.invalidPhoto }
            #if DEBUG
                recordStage("photoSource type=\(sourceType) bytes=\(data.count)")
            #endif

            let watermark = try PhotoWatermark()
            guard
                let image = renderedImage(
                    from: data,
                    ratio: ratio,
                    quarterTurns: quarterTurns,
                    drawOverlay: { size in watermark.draw(in: size) }
                ), let pixels = image.cgImage
            else { throw ProcessingError.invalidPhoto }
            try Task.checkCancellation()
            recordStage("photoRendered")

            // Preserve the content identifier that pairs a Live Photo with its movie.
            let properties = NSMutableDictionary(dictionary: sourceProperties)
            properties[kCGImagePropertyOrientation] = 1
            properties.removeObject(forKey: kCGImagePropertyPixelWidth)
            properties.removeObject(forKey: kCGImagePropertyPixelHeight)
            let output = NSMutableData()
            recordStage("photoEncodeStarted")
            guard let destination = CGImageDestinationCreateWithData(output, sourceType, 1, nil)
            else { throw ProcessingError.invalidPhoto }
            CGImageDestinationAddImage(destination, pixels, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                throw ProcessingError.invalidPhoto
            }
            #if DEBUG
                recordStage(
                    "photoProcessingFinished type=\(sourceType) bytes=\(output.length) width=\(pixels.width) height=\(pixels.height)"
                )
            #else
                recordStage("photoProcessingFinished")
            #endif
            let data = output as Data
            return (data, thumbnail(from: data))
        }
        if let thumbnail = output.thumbnail { await onProcessed(thumbnail) }
        return output.data
    }

    private func thumbnail(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 256,
                    kCGImageSourceShouldCacheImmediately: true,
                ] as CFDictionary
            )
        else { return nil }
        return UIImage(cgImage: image)
    }

    /// Normalizes orientation, crops in portrait coordinates, and applies the final
    /// quarter turn in one render. Callers supply -1, 0, or 1 quarter turns.
    private func renderedImage(
        from data: Data,
        ratio: PhotoAspectRatio,
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
            sourceWidth / ratio.dimensions.width,
            sourceHeight / ratio.dimensions.height
        )
        guard units > 0 else { return nil }
        let cropWidth = units * ratio.dimensions.width
        let cropHeight = units * ratio.dimensions.height
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
