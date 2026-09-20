//
//  LivePhotoProcessor.swift
//  Framewise legacy camera snapshot
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
        outputPlan: CameraOutputPlan,
        performanceCapture: CameraPerformance.Capture
    ) async throws -> CameraCaptureResult {
        let processingTimer = CameraPerformance.startTimer()
        var outcome = "success"
        defer {
            CameraPerformance.record(
                "output_processing_total",
                timer: processingTimer,
                capture: performanceCapture,
                outcome: outcome
            )
        }

        guard Self.isValid(outputPlan) else {
            outcome = "failure"
            throw CameraError.processingFailed("拍摄画幅与模板比例不一致。")
        }

        switch capture {
        case .photo(let data):
            do {
                return .photo(
                    try processPhotoData(
                        data,
                        outputPlan: outputPlan,
                        performanceCapture: performanceCapture
                    )
                )
            } catch {
                outcome = "failure"
                throw error
            }
        case .livePhoto(let photoData, let pairedVideoURL):
            let processedMovieURL = Self.makeProcessedMovieURL()
            defer {
                try? FileManager.default.removeItem(at: pairedVideoURL)
            }

            do {
                let processedPhotoData = try processPhotoData(
                    photoData,
                    outputPlan: outputPlan,
                    performanceCapture: performanceCapture
                )
                try await processMovie(
                    at: pairedVideoURL,
                    outputURL: processedMovieURL,
                    outputPlan: outputPlan,
                    performanceCapture: performanceCapture
                )

                return .livePhoto(
                    photoData: processedPhotoData,
                    pairedVideoURL: processedMovieURL
                )
            } catch {
                outcome = "failure"
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
        outputPlan: CameraOutputPlan,
        performanceCapture: CameraPerformance.Capture
    ) throws -> Data {
        let timer = CameraPerformance.startTimer()
        var outcome = "success"
        defer {
            CameraPerformance.record(
                "photo_crop_and_encode",
                timer: timer,
                capture: performanceCapture,
                outcome: outcome
            )
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let sourceType = CGImageSourceGetType(source),
              let image = CIImage(
                  data: data,
                  options: [.applyOrientationProperty: true]
              ) else {
            outcome = "failure"
            throw CameraError.processingFailed("无法读取相机照片。")
        }

        let visibleRect = Self.pixelRect(
            for: outputPlan.normalizedPreviewRect,
            in: image.extent
        )
        let cropRect = CameraOutputGeometry.centeredCropRect(
            in: visibleRect,
            targetAspectRatio: outputPlan.sourceCropAspectRatio
        )
        guard !cropRect.isNull,
              cropRect.width > 0,
              cropRect.height > 0 else {
            outcome = "failure"
            throw CameraError.processingFailed("取景区域无效。")
        }
        let previewImage = Self.normalizedImage(
            image.cropped(to: cropRect)
        )
        let outputImage = Self.rotatedImage(
            previewImage,
            clockwiseRotationAngle:
                outputPlan.captureToOutputRotationAngle
        )
        guard Self.hasAspectRatio(
            outputImage.extent.size,
            targetAspectRatio: outputPlan.targetAspectRatio
        ) else {
            outcome = "failure"
            throw CameraError.processingFailed("照片输出比例不正确。")
        }

        guard let renderedImage = imageContext.createCGImage(
            outputImage,
            from: outputImage.extent
        ) else {
            outcome = "failure"
            throw CameraError.processingFailed("无法生成裁切后的照片。")
        }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            sourceType,
            1,
            nil
        ) else {
            outcome = "failure"
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
            outcome = "failure"
            throw CameraError.processingFailed("照片编码失败。")
        }

        return outputData as Data
    }

    private func processMovie(
        at inputURL: URL,
        outputURL: URL,
        outputPlan: CameraOutputPlan,
        performanceCapture: CameraPerformance.Capture
    ) async throws {
        let timer = CameraPerformance.startTimer()
        var outcome = "success"
        defer {
            CameraPerformance.record(
                "live_movie_crop_and_export",
                timer: timer,
                capture: performanceCapture,
                outcome: outcome
            )
        }

        do {
            try await processMovieContents(
                at: inputURL,
                outputURL: outputURL,
                outputPlan: outputPlan
            )
        } catch {
            outcome = "failure"
            throw error
        }
    }

    private func processMovieContents(
        at inputURL: URL,
        outputURL: URL,
        outputPlan: CameraOutputPlan
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
        let visibleRect = Self.pixelRect(
            for: outputPlan.normalizedPreviewRect,
            in: orientedBounds
        )
        let requestedCropRect = CameraOutputGeometry.centeredCropRect(
            in: visibleRect,
            targetAspectRatio: outputPlan.sourceCropAspectRatio
        )
        guard !requestedCropRect.isNull,
              requestedCropRect.width > 0,
              requestedCropRect.height > 0 else {
            throw CameraError.processingFailed("实况照片取景区域无效。")
        }
        let renderSize = CameraOutputGeometry.evenPixelSize(
            requestedCropRect.size
        )
        let cropRect = CGRect(
            x: min(
                max(requestedCropRect.minX, orientedBounds.minX),
                orientedBounds.maxX - renderSize.width
            ),
            y: min(
                max(requestedCropRect.minY, orientedBounds.minY),
                orientedBounds.maxY - renderSize.height
            ),
            width: renderSize.width,
            height: renderSize.height
        )
        let normalizedTransform = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedBounds.minX,
                y: -transformedBounds.minY
            )
        )
        let previewTransform = normalizedTransform.concatenating(
            CGAffineTransform(
                translationX: -cropRect.minX,
                y: -cropRect.minY
            )
        )
        let outputRotation = CameraOutputGeometry
            .normalizedRotationTransform(
                clockwiseRotationAngle:
                    outputPlan.captureToOutputRotationAngle,
                sourceSize: renderSize
            )
        let outputTransform = previewTransform.concatenating(
            outputRotation.transform
        )
        let outputSize = CameraOutputGeometry.evenPixelSize(
            outputRotation.outputSize
        )
        guard Self.hasAspectRatio(
            outputSize,
            targetAspectRatio: outputPlan.targetAspectRatio
        ) else {
            throw CameraError.processingFailed("实况照片输出比例不正确。")
        }
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
                renderSize: outputSize,
                transform: outputTransform
            )
        } else {
            videoComposition = Self.makeLegacyVideoComposition(
                track: videoTrack,
                duration: duration,
                frameDuration: frameDuration,
                renderSize: outputSize,
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

    nonisolated private static func isValid(
        _ outputPlan: CameraOutputPlan
    ) -> Bool {
        let sourceRatio = outputPlan.sourceCropAspectRatio
        let targetRatio = outputPlan.targetAspectRatio
        guard sourceRatio > 0, targetRatio > 0 else {
            return false
        }

        let quarterTurns = CameraOutputGeometry.normalizedQuarterTurns(
            outputPlan.captureToOutputRotationAngle
        )
        let projectedRatio = quarterTurns.isMultiple(of: 2)
            ? sourceRatio
            : 1 / sourceRatio
        return abs(projectedRatio - targetRatio) / targetRatio < 0.01
    }

    nonisolated private static func normalizedImage(
        _ image: CIImage
    ) -> CIImage {
        image.transformed(
            by: CGAffineTransform(
                translationX: -image.extent.minX,
                y: -image.extent.minY
            )
        )
    }

    nonisolated private static func pixelRect(
        for normalizedRect: CGRect,
        in extent: CGRect
    ) -> CGRect {
        let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let rect = normalizedRect.standardized.intersection(unitRect)
        guard extent.width > 0,
              extent.height > 0,
              !rect.isNull,
              rect.width > 0,
              rect.height > 0 else {
            return extent
        }

        // Capture output coordinates use a top-left origin. Core Image uses a
        // bottom-left origin, so flip only the normalized y coordinate.
        return CGRect(
            x: extent.minX + rect.minX * extent.width,
            y: extent.minY + (1 - rect.maxY) * extent.height,
            width: rect.width * extent.width,
            height: rect.height * extent.height
        ).intersection(extent)
    }

    nonisolated private static func hasAspectRatio(
        _ size: CGSize,
        targetAspectRatio: Double
    ) -> Bool {
        guard size.width > 0,
              size.height > 0,
              targetAspectRatio > 0 else {
            return false
        }

        let actualRatio = Double(size.width / size.height)
        return abs(actualRatio - targetAspectRatio) / targetAspectRatio < 0.01
    }

    nonisolated private static func rotatedImage(
        _ image: CIImage,
        clockwiseRotationAngle: Double
    ) -> CIImage {
        let orientation: CGImagePropertyOrientation

        switch CameraOutputGeometry.normalizedQuarterTurns(
            clockwiseRotationAngle
        ) {
        case 1:
            orientation = .right
        case 2:
            orientation = .down
        case 3:
            orientation = .left
        default:
            orientation = .up
        }

        return normalizedImage(image.oriented(orientation))
    }

    nonisolated private static func makeProcessedMovieURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Framewise-Processed-\(UUID().uuidString)")
            .appendingPathExtension("mov")
    }
}
