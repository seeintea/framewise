//
//  LivePhotoProcessor.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

@preconcurrency import AVFoundation
import CoreImage
import ImageIO

actor LivePhotoProcessor {
    private let imageContext = CIContext()

    func process(
        _ capture: CameraCaptureResult,
        targetAspectRatio: Double
    ) async throws -> CameraCaptureResult {
        guard targetAspectRatio > 0 else {
            throw CameraError.processingFailed("无效的输出画幅比例。")
        }

        switch capture {
        case .photo(let data):
            return .photo(
                try processPhotoData(data, targetAspectRatio: targetAspectRatio)
            )
        case .livePhoto(let photoData, let pairedVideoURL):
            let processedMovieURL = Self.makeProcessedMovieURL()

            do {
                let processedPhotoData = try processPhotoData(
                    photoData,
                    targetAspectRatio: targetAspectRatio
                )
                try await processMovie(
                    at: pairedVideoURL,
                    outputURL: processedMovieURL,
                    targetAspectRatio: targetAspectRatio
                )
                try? FileManager.default.removeItem(at: pairedVideoURL)

                return .livePhoto(
                    photoData: processedPhotoData,
                    pairedVideoURL: processedMovieURL
                )
            } catch {
                try? FileManager.default.removeItem(at: processedMovieURL)
                if let cameraError = error as? CameraError {
                    throw cameraError
                }
                throw CameraError.processingFailed(error.localizedDescription)
            }
        }
    }

    private func processPhotoData(
        _ data: Data,
        targetAspectRatio: Double
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let sourceType = CGImageSourceGetType(source),
              let image = CIImage(
                  data: data,
                  options: [.applyOrientationProperty: true]
              ) else {
            throw CameraError.processingFailed("无法读取相机照片。")
        }

        let cropRect = CameraOutputGeometry.centeredCropRect(
            in: image.extent,
            targetAspectRatio: targetAspectRatio
        )
        let croppedImage = image
            .cropped(to: cropRect)
            .transformed(
                by: CGAffineTransform(
                    translationX: -cropRect.minX,
                    y: -cropRect.minY
                )
            )

        guard let renderedImage = imageContext.createCGImage(
            croppedImage,
            from: croppedImage.extent
        ) else {
            throw CameraError.processingFailed("无法生成裁切后的照片。")
        }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            sourceType,
            1,
            nil
        ) else {
            throw CameraError.processingFailed("无法创建照片输出。")
        }

        let properties = NSMutableDictionary(
            dictionary: CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [AnyHashable: Any] ?? [:]
        )
        properties[kCGImagePropertyOrientation] = 1
        properties.removeObject(forKey: kCGImagePropertyPixelWidth)
        properties.removeObject(forKey: kCGImagePropertyPixelHeight)
        CGImageDestinationAddImage(
            destination,
            renderedImage,
            properties as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            throw CameraError.processingFailed("照片编码失败。")
        }

        return outputData as Data
    }

    private func processMovie(
        at inputURL: URL,
        outputURL: URL,
        targetAspectRatio: Double
    ) async throws {
        let asset = AVURLAsset(url: inputURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw CameraError.processingFailed("实况照片缺少视频画面。")
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        let transformedBounds = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
        let orientedBounds = CGRect(
            origin: .zero,
            size: CGSize(
                width: abs(transformedBounds.width),
                height: abs(transformedBounds.height)
            )
        )
        let requestedCropRect = CameraOutputGeometry.centeredCropRect(
            in: orientedBounds,
            targetAspectRatio: targetAspectRatio
        )
        let renderSize = CameraOutputGeometry.evenPixelSize(
            requestedCropRect.size
        )
        let cropRect = CGRect(
            x: orientedBounds.midX - renderSize.width / 2,
            y: orientedBounds.midY - renderSize.height / 2,
            width: renderSize.width,
            height: renderSize.height
        )
        let normalizedTransform = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedBounds.minX,
                y: -transformedBounds.minY
            )
        )
        let outputTransform = normalizedTransform.concatenating(
            CGAffineTransform(
                translationX: -cropRect.minX,
                y: -cropRect.minY
            )
        )
        let frameRate = nominalFrameRate > 0 ? nominalFrameRate : 30
        let frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(max(1, frameRate.rounded()))
        )
        let videoComposition: AVVideoComposition

        if #available(iOS 26.0, *) {
            videoComposition = Self.makeVideoComposition(
                track: videoTrack,
                duration: duration,
                frameDuration: frameDuration,
                renderSize: renderSize,
                transform: outputTransform
            )
        } else {
            videoComposition = Self.makeLegacyVideoComposition(
                track: videoTrack,
                duration: duration,
                frameDuration: frameDuration,
                renderSize: renderSize,
                transform: outputTransform
            )
        }

        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw CameraError.processingFailed("无法创建实况照片处理任务。")
        }

        exporter.videoComposition = videoComposition
        exporter.metadata = try await asset.load(.metadata)
        try await exporter.export(to: outputURL, as: .mov)
    }

    @available(iOS 26.0, *)
    nonisolated private static func makeVideoComposition(
        track: AVAssetTrack,
        duration: CMTime,
        frameDuration: CMTime,
        renderSize: CGSize,
        transform: CGAffineTransform
    ) -> AVVideoComposition {
        var layerConfiguration =
            AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
        layerConfiguration.setTransform(transform, at: .zero)
        let layerInstruction = AVVideoCompositionLayerInstruction(
            configuration: layerConfiguration
        )
        let instructionConfiguration =
            AVVideoCompositionInstruction.Configuration(
                layerInstructions: [layerInstruction],
                timeRange: CMTimeRange(start: .zero, duration: duration)
            )
        let instruction = AVVideoCompositionInstruction(
            configuration: instructionConfiguration
        )
        let configuration = AVVideoComposition.Configuration(
            frameDuration: frameDuration,
            instructions: [instruction],
            renderSize: renderSize,
            sourceTrackIDForFrameTiming: track.trackID
        )
        return AVVideoComposition(configuration: configuration)
    }

    @available(iOS, introduced: 18.0, obsoleted: 26.0)
    nonisolated private static func makeLegacyVideoComposition(
        track: AVAssetTrack,
        duration: CMTime,
        frameDuration: CMTime,
        renderSize: CGSize,
        transform: CGAffineTransform
    ) -> AVVideoComposition {
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: track
        )
        layerInstruction.setTransform(transform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]

        let composition = AVMutableVideoComposition()
        composition.frameDuration = frameDuration
        composition.renderSize = renderSize
        composition.instructions = [instruction]
        return composition
    }

    nonisolated private static func makeProcessedMovieURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Framewise-Processed-\(UUID().uuidString)")
            .appendingPathExtension("mov")
    }
}
