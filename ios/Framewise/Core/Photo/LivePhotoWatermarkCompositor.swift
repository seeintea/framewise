//
//  LivePhotoWatermarkCompositor.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import AVFoundation
import CoreImage

/// Explicit output geometry for Live Photo watermarking. Camera MOVs can have
/// a smaller clean aperture than their encoded pixel buffer.
nonisolated final class LivePhotoWatermarkCompositor: NSObject, AVVideoCompositing {
    final class Instruction: NSObject, AVVideoCompositionInstructionProtocol {
        let timeRange: CMTimeRange
        let enablePostProcessing = false
        let containsTweening = false
        var requiredSourceTrackIDs: [NSValue]? { [NSNumber(value: trackID)] }
        let passthroughTrackID = kCMPersistentTrackID_Invalid
        let trackID: CMPersistentTrackID
        let naturalSize: CGSize
        let transform: CGAffineTransform
        let overlay: CIImage
        let context: CIContext

        init(
            trackID: CMPersistentTrackID, duration: CMTime, naturalSize: CGSize,
            transform: CGAffineTransform, overlay: CIImage, context: CIContext
        ) {
            self.trackID = trackID
            timeRange = CMTimeRange(start: .zero, duration: duration)
            self.naturalSize = naturalSize
            self.transform = transform
            self.overlay = overlay
            self.context = context
        }
    }

    private enum RenderingError: Error {
        case missingSourceOrInstruction
        case invalidCleanAperture
        case outputBufferUnavailable
    }

    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [
            kCVPixelBufferPixelFormatTypeKey as String: [
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelFormatType_32BGRA,
            ]
        ]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    // Finish each request synchronously on AVFoundation's rendering thread.
    // Cancellation waits for the current render; no unstructured tasks retain frames.
    private let renderLock = NSLock()

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func cancelAllPendingVideoCompositionRequests() {
        renderLock.lock()
        renderLock.unlock()
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        renderLock.lock()
        defer { renderLock.unlock() }
        autoreleasepool {
            do {
                guard let instruction = request.videoCompositionInstruction as? Instruction else {
                    throw RenderingError.missingSourceOrInstruction
                }
                if #available(iOS 26.0, *) {
                    guard
                        let source = request.sourceReadOnlyPixelBuffer(
                            byTrackID: instruction.trackID)
                    else { throw RenderingError.missingSourceOrInstruction }
                    let output = try request.renderContext.makeMutablePixelBuffer()
                    try source.withUnsafeBuffer { sourceBuffer in
                        try output.withUnsafeBuffer { outputBuffer in
                            try Self.render(
                                sourceBuffer, to: outputBuffer,
                                instruction: instruction, renderContext: request.renderContext)
                        }
                    }
                    request.finish(withComposedPixelBuffer: CVReadOnlyPixelBuffer(output))
                } else {
                    guard let source = request.sourceFrame(byTrackID: instruction.trackID)
                    else { throw RenderingError.missingSourceOrInstruction }
                    guard let output = request.renderContext.newPixelBuffer()
                    else { throw RenderingError.outputBufferUnavailable }
                    try Self.render(
                        source, to: output, instruction: instruction,
                        renderContext: request.renderContext)
                    request.finish(withComposedVideoFrame: output)
                }
            } catch {
                request.finish(with: error)
            }
        }
    }

    private static func render(
        _ source: CVPixelBuffer,
        to output: CVPixelBuffer,
        instruction: Instruction,
        renderContext: AVVideoCompositionRenderContext
    ) throws {
        let cleanRect = CVImageBufferGetCleanRect(source)
        guard cleanRect.width > 0, cleanRect.height > 0 else {
            throw RenderingError.invalidCleanAperture
        }
        // Clean aperture uses Core Image's bottom-left coordinates. Normalize it
        // before applying the same top-left track/crop/turn transform as B and C.
        let image = CIImage(cvPixelBuffer: source)
            .cropped(to: cleanRect)
            .transformed(by: CGAffineTransform(translationX: -cleanRect.minX, y: -cleanRect.minY))
            .transformed(
                by: CGAffineTransform(
                    scaleX: instruction.naturalSize.width / cleanRect.width,
                    y: instruction.naturalSize.height / cleanRect.height
                ))
        let flipSource = CGAffineTransform(
            a: 1, b: 0, c: 0, d: -1,
            tx: 0, ty: instruction.naturalSize.height)
        let flipOutput = CGAffineTransform(
            a: 1, b: 0, c: 0, d: -1,
            tx: 0, ty: renderContext.size.height)
        let transformed = image.transformed(
            by:
                flipSource
                .concatenating(instruction.transform).concatenating(flipOutput))
        let result = instruction.overlay.composited(over: transformed)
            .cropped(to: CGRect(origin: .zero, size: renderContext.size))
            .transformed(by: renderContext.renderTransform)
        instruction.context.render(result, to: output)
    }
}
