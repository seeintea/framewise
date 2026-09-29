//
//  LivePhotoProcessor.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation
import CoreGraphics
import CoreImage
import UIKit

/// Applies the same centered portrait crop and final quarter turn to both Live Photo resources.
actor LivePhotoProcessor {
    enum ProcessingError: Error {
        case invalidMovie
        case exportUnavailable
    }

    struct Result {
        let photoData: Data
        let movieURL: URL
    }

    private var watermarkContext: CIContext?

    func process(
        photoData: Data,
        movieURL: URL,
        ratio: PhotoAspectRatio,
        quarterTurns: Int,
        recordStage: @escaping @Sendable (String) -> Void,
        onPhotoProcessed: @escaping @MainActor @Sendable (UIImage) -> Void
    ) async throws -> Result {
        // The still render/encode runs on its own actor while AVFoundation
        // loads and exports the movie. Neither resource waits for the other to start.
        async let processedPhoto = PhotoProcessor.shared.process(
            photoData,
            ratio: ratio,
            quarterTurns: quarterTurns,
            recordStage: recordStage,
            onProcessed: onPhotoProcessed
        )
        recordStage("movieProcessingStarted")
        let outputURL = try await processMovie(
            movieURL,
            ratio: ratio,
            quarterTurns: quarterTurns,
            recordStage: recordStage
        )
        recordStage("movieProcessingFinished")
        do {
            return try await Result(
                photoData: processedPhoto,
                movieURL: outputURL
            )
        } catch {
            // A successful movie export still needs cleanup if the parallel still failed.
            if outputURL != movieURL {
                try? FileManager.default.removeItem(at: outputURL)
            }
            throw error
        }
    }

    private func processMovie(
        _ inputURL: URL,
        ratio: PhotoAspectRatio,
        quarterTurns: Int,
        recordStage: @Sendable (String) -> Void
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard
            let track = try await asset.loadTracks(withMediaType: .video).first
        else {
            throw ProcessingError.invalidMovie
        }
        let (naturalSize, preferredTransform, frameRate) = try await track.load(
            .naturalSize,
            .preferredTransform,
            .nominalFrameRate
        )
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
        recordStage("movieTranscodeStarted")
        let outputSize = CGSize(
            width: abs(rotatedBounds.width),
            height: abs(rotatedBounds.height)
        )
        let frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(max(1, frameRate.rounded()))
        )
        let composition = try coreImageComposition(
            track: track,
            duration: duration,
            frameDuration: frameDuration,
            naturalSize: naturalSize,
            outputSize: outputSize,
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

    private func coreImageComposition(
        track: AVAssetTrack,
        duration: CMTime,
        frameDuration: CMTime,
        naturalSize: CGSize,
        outputSize: CGSize,
        transform: CGAffineTransform
    ) throws -> AVVideoComposition {
        let context: CIContext
        if let watermarkContext {
            context = watermarkContext
        } else {
            context = CIContext(options: [
                .cacheIntermediates: false, .name: "LivePhotoWatermark",
            ])
            watermarkContext = context
        }
        let instruction = LivePhotoWatermarkCompositor.Instruction(
            trackID: track.trackID,
            duration: duration,
            naturalSize: naturalSize,
            transform: transform,
            overlay: try PhotoWatermark().coreImageOverlay(for: outputSize),
            context: context
        )
        if #available(iOS 26.0, *) {
            return AVVideoComposition(
                configuration: .init(
                    customVideoCompositorClass: LivePhotoWatermarkCompositor
                        .self,
                    frameDuration: frameDuration,
                    instructions: [instruction],
                    renderSize: outputSize,
                    sourceTrackIDForFrameTiming: track.trackID
                )
            )
        }
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass =
            LivePhotoWatermarkCompositor.self
        composition.frameDuration = frameDuration
        composition.instructions = [instruction]
        composition.renderSize = outputSize
        composition.sourceTrackIDForFrameTiming = track.trackID
        return composition
    }
}
