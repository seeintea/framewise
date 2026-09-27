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
        timing: CameraCaptureTiming
    ) throws -> Data {
        try Task.checkCancellation()
        timing.record("photoProcessingStarted")
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let sourceType = CGImageSourceGetType(source),
                let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                    as? [CFString: Any]
            else { throw ProcessingError.invalidPhoto }

            if let orientation = sourceProperties[kCGImagePropertyOrientation] as? UInt32,
                let sourceOrientation = CGImagePropertyOrientation(rawValue: orientation),
                let width = sourceProperties[kCGImagePropertyPixelWidth] as? Int,
                let height = sourceProperties[kCGImagePropertyPixelHeight] as? Int,
                canReusePixels(
                    width: width,
                    height: height,
                    orientation: sourceOrientation,
                    ratio: ratio,
                    quarterTurns: quarterTurns
                )
            {
                if sourceOrientation == .up {
                    timing.record("photoPassthrough")
                    return data
                }
                // Source orientation and final rotation cancel: the existing pixel
                // matrix already IS the normalized output, so only clear its EXIF turn.
                let output = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(
                    output, sourceType, CGImageSourceGetCount(source), nil
                ) else { throw ProcessingError.invalidPhoto }
                let options = [kCGImageDestinationOrientation: 1] as CFDictionary
                var error: Unmanaged<CFError>?
                guard CGImageDestinationCopyImageSource(destination, source, options, &error)
                else {
                    if let error { throw error.takeRetainedValue() }
                    throw ProcessingError.invalidPhoto
                }
                // CopyImageSource finalizes the destination itself, without recompression.
                timing.record("photoPixelsReused")
                return output as Data
            }

            guard let image = ratio.renderedImage(from: data, quarterTurns: quarterTurns),
                let pixels = image.cgImage
            else { throw ProcessingError.invalidPhoto }
            try Task.checkCancellation()
            timing.record("photoRendered")

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
            timing.record("photoProcessingFinished")
            return output as Data
        }
    }

    private func canReusePixels(
        width: Int,
        height: Int,
        orientation: CGImagePropertyOrientation,
        ratio: PhotoAspectRatio,
        quarterTurns: Int
    ) -> Bool {
        // Reflections never cancel a rotation. Leave mirrored captures on the renderer.
        switch (orientation, quarterTurns) {
        case (.up, 0), (.right, -1), (.left, 1): break
        default: return false
        }
        let dimensions = ratio.dimensions
        let outputWidth = quarterTurns == 0 ? dimensions.width : dimensions.height
        let outputHeight = quarterTurns == 0 ? dimensions.height : dimensions.width
        return width > 0 && height > 0
            && width % outputWidth == 0 && height % outputHeight == 0
            && width / outputWidth == height / outputHeight
    }
}
