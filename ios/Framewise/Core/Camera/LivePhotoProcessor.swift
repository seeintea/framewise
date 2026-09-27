//
//  LivePhotoProcessor.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import AVFoundation
import CoreGraphics

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

    func process(
        photoData: Data,
        movieURL: URL,
        ratio: PhotoAspectRatio,
        quarterTurns: Int,
        timing: CameraCaptureTiming
    ) async throws -> Result {
        // The still render/encode runs on its own actor while AVFoundation
        // loads and exports the movie. Neither resource waits for the other to start.
        async let processedPhoto = CameraPhotoProcessor.shared.process(
            photoData,
            ratio: ratio,
            quarterTurns: quarterTurns,
            timing: timing
        )
        timing.record("movieProcessingStarted")
        let outputURL = try await processMovie(
            movieURL,
            ratio: ratio,
            quarterTurns: quarterTurns,
            timing: timing
        )
        timing.record("movieProcessingFinished")
        do {
            return try await Result(photoData: processedPhoto, movieURL: outputURL)
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
        timing: CameraCaptureTiming
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard
            let track = try await asset.loadTracks(withMediaType: .video).first
        else {
            throw ProcessingError.invalidMovie
        }
        let (naturalSize, preferredTransform, frameRate) = try await track.load(
            .naturalSize, .preferredTransform, .nominalFrameRate
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
        let needsCrop = !(
            abs(cropSize.width - orientedSize.width) < 0.5 &&
            abs(cropSize.height - orientedSize.height) < 0.5
        )
        if quarterTurns == 0, !needsCrop {
            timing.record("moviePassthrough")
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
        if !needsCrop {
            // A whole-frame turn needs only a display transform. Editing the existing
            // movie header retains audio, timed metadata and compressed video samples.
            let movie = AVMutableMovie(url: inputURL)
            guard let movieTrack = try await movie.loadTracks(withMediaType: .video).first
            else { throw ProcessingError.invalidMovie }
            movieTrack.preferredTransform = transform
            try movie.writeHeader(
                to: inputURL,
                fileType: .mov,
                options: .addMovieHeaderToDestination
            )
            timing.record("movieTransformUpdated")
            return inputURL
        }
        timing.record("movieTranscodeStarted")
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
