//
//  LivePhotoProcessor.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation
import ImageIO
import UIKit

/// Applies the same centered portrait crop and final quarter turn to both Live Photo resources.
actor LivePhotoProcessor {
    enum ProcessingError: Error {
        case invalidPhoto
        case invalidMovie
        case exportUnavailable
    }

    struct Result {
        let photoData: Data
        let movieURL: URL
    }

    func process(
        photoData: Data,
        movieURL: URL,
        ratio: PhotoAspectRatio,
        quarterTurns: Int
    ) async throws -> Result {
        let processedPhoto = try processPhoto(
            photoData,
            ratio: ratio,
            quarterTurns: quarterTurns
        )
        let outputURL = try await processMovie(
            movieURL,
            ratio: ratio,
            quarterTurns: quarterTurns
        )
        return Result(photoData: processedPhoto, movieURL: outputURL)
    }

    private func processPhoto(
        _ data: Data,
        ratio: PhotoAspectRatio,
        quarterTurns: Int
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let sourceType = CGImageSourceGetType(source),
            let image = ratio.renderedImage(
                from: data,
                quarterTurns: quarterTurns
            ),
            let pixels = image.cgImage
        else {
            throw ProcessingError.invalidPhoto
        }

        // AVFoundation stores the Live Photo content identifier in the source metadata.
        // Keep it when replacing the pixels so Photos can pair this still with the movie.
        let properties = NSMutableDictionary(
            dictionary: CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [AnyHashable: Any] ?? [:]
        )
        properties[kCGImagePropertyOrientation] = 1
        properties.removeObject(forKey: kCGImagePropertyPixelWidth)
        properties.removeObject(forKey: kCGImagePropertyPixelHeight)
        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output,
                sourceType,
                1,
                nil
            )
        else { throw ProcessingError.invalidPhoto }
        CGImageDestinationAddImage(
            destination,
            pixels,
            properties as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ProcessingError.invalidPhoto
        }
        return output as Data
    }

    private func processMovie(
        _ inputURL: URL,
        ratio: PhotoAspectRatio,
        quarterTurns: Int
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard
            let track = try await asset.loadTracks(withMediaType: .video).first
        else {
            throw ProcessingError.invalidMovie
        }
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let frameRate = try await track.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        let orientedBounds = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
        let orientedSize = CGSize(
            width: abs(orientedBounds.width),
            height: abs(orientedBounds.height)
        )
        let dimensions = ratio.dimensions
        let units =
            Int(
                min(
                    orientedSize.width / CGFloat(dimensions.width),
                    orientedSize.height / CGFloat(dimensions.height)
                )
            ) / 2 * 2
        guard units > 0 else { throw ProcessingError.invalidMovie }
        let cropSize = CGSize(
            width: units * dimensions.width,
            height: units * dimensions.height
        )
        if quarterTurns == 0,
            abs(cropSize.width - orientedSize.width) < 0.5,
            abs(cropSize.height - orientedSize.height) < 0.5
        {
            return inputURL
        }
        let cropOrigin = CGPoint(
            x: (orientedSize.width - cropSize.width) / 2,
            y: (orientedSize.height - cropSize.height) / 2
        )
        let normalized = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -orientedBounds.minX,
                y: -orientedBounds.minY
            )
        ).concatenating(
            CGAffineTransform(translationX: -cropOrigin.x, y: -cropOrigin.y)
        )
        let rotation = CGAffineTransform(
            rotationAngle: CGFloat(quarterTurns) * .pi / 2
        )
        let rotatedBounds = CGRect(origin: .zero, size: cropSize).applying(
            rotation
        )
        let transform = normalized.concatenating(rotation).concatenating(
            CGAffineTransform(
                translationX: -rotatedBounds.minX,
                y: -rotatedBounds.minY
            )
        )
        let outputSize = CGSize(
            width: abs(rotatedBounds.width),
            height: abs(rotatedBounds.height)
        )
        let frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(max(1, frameRate.rounded()))
        )
        let composition = Self.videoComposition(
            track: track,
            duration: duration,
            frameDuration: frameDuration,
            renderSize: outputSize,
            transform: transform
        )
        guard
            let exporter = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetHighestQuality
            )
        else { throw ProcessingError.exportUnavailable }
        exporter.videoComposition = composition
        exporter.metadata = try await asset.load(.metadata)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "Framewise-processed-\(UUID().uuidString).mov"
            )
        do {
            try await exporter.export(to: outputURL, as: .mov)
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private static func videoComposition(
        track: AVAssetTrack,
        duration: CMTime,
        frameDuration: CMTime,
        renderSize: CGSize,
        transform: CGAffineTransform
    ) -> AVVideoComposition {
        if #available(iOS 26.0, *) {
            var layer = AVVideoCompositionLayerInstruction.Configuration(
                assetTrack: track
            )
            layer.setTransform(transform, at: .zero)
            let instruction = AVVideoCompositionInstruction(
                configuration: .init(
                    layerInstructions: [
                        AVVideoCompositionLayerInstruction(configuration: layer)
                    ],
                    timeRange: CMTimeRange(start: .zero, duration: duration)
                )
            )
            return AVVideoComposition(
                configuration: .init(
                    frameDuration: frameDuration,
                    instructions: [instruction],
                    renderSize: renderSize,
                    sourceTrackIDForFrameTiming: track.trackID
                )
            )
        }
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layer]
        let composition = AVMutableVideoComposition()
        composition.frameDuration = frameDuration
        composition.renderSize = renderSize
        composition.instructions = [instruction]
        return composition
    }
}
