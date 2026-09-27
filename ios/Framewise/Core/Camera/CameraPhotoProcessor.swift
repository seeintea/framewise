import ImageIO
import UIKit

/// Encodes the final pixels once, retaining the source camera and Live Photo metadata.
actor CameraPhotoProcessor {
    static let shared = CameraPhotoProcessor()

    enum ProcessingError: Error { case invalidPhoto }

    // Serialize full-resolution still renders to bound memory use during repeated shots.
    // A separate actor lets movie exports progress concurrently without blocking the UI.
    func process(
        _ data: Data,
        ratio: PhotoAspectRatio,
        quarterTurns: Int,
        performance: CameraCapturePerformance
    ) throws -> Data {
        try Task.checkCancellation()
        performance.record("photoProcessingStarted")
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let sourceType = CGImageSourceGetType(source),
                let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                    as? [CFString: Any]
            else { throw ProcessingError.invalidPhoto }

            let watermark = try CameraWatermark()
            guard let image = ratio.renderedImage(
                from: data,
                quarterTurns: quarterTurns,
                drawOverlay: { size in watermark.draw(in: size) }
            ), let pixels = image.cgImage else { throw ProcessingError.invalidPhoto }
            try Task.checkCancellation()
            performance.record("photoRendered")

            // Preserve the content identifier that pairs a Live Photo with its movie.
            let properties = NSMutableDictionary(dictionary: sourceProperties)
            properties[kCGImagePropertyOrientation] = 1
            properties.removeObject(forKey: kCGImagePropertyPixelWidth)
            properties.removeObject(forKey: kCGImagePropertyPixelHeight)
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, sourceType, 1, nil)
            else { throw ProcessingError.invalidPhoto }
            CGImageDestinationAddImage(destination, pixels, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                throw ProcessingError.invalidPhoto
            }
            performance.record("photoProcessingFinished")
            return output as Data
        }
    }
}
