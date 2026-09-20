//
//  CameraFramingSnapshot.swift
//  Framewise
//
//  Created by Codex on 2026/9/20.
//

import CoreGraphics

struct CameraFramingSnapshot: Equatable, Sendable {
    /// The cardinal rotation applied by the photo output at capture time.
    let captureRotationAngle: Double

    /// Matches the preview connection so the saved result preserves its view.
    let isMirrored: Bool

    /// Rotates capture-oriented pixels into the preview view's coordinates.
    let captureToPreviewRotationAngle: Double

    /// The sensor region that is actually visible through the preview layer.
    /// This includes the preview layer's aspect-fill crop.
    let visibleMetadataRect: CGRect
}

struct CameraOutputPlan: Equatable, Sendable {
    let framingSnapshot: CameraFramingSnapshot
    let previewAspectRatio: Double
    let targetAspectRatio: Double

    /// Rotates capture-oriented preview content into template coordinates.
    let captureToOutputRotationAngle: Double

    /// The visible preview region mapped into the oriented photo output.
    let normalizedPreviewRect: CGRect

    nonisolated init(
        framingSnapshot: CameraFramingSnapshot,
        previewAspectRatio: Double,
        targetAspectRatio: Double,
        captureToOutputRotationAngle: Double,
        normalizedPreviewRect: CGRect = CGRect(
            x: 0,
            y: 0,
            width: 1,
            height: 1
        )
    ) {
        self.framingSnapshot = framingSnapshot
        self.previewAspectRatio = previewAspectRatio
        self.targetAspectRatio = targetAspectRatio
        self.captureToOutputRotationAngle = captureToOutputRotationAngle
        self.normalizedPreviewRect = normalizedPreviewRect
    }

    nonisolated var sourceCropAspectRatio: Double {
        let quarterTurns = CameraOutputGeometry.normalizedQuarterTurns(
            framingSnapshot.captureToPreviewRotationAngle
        )
        return quarterTurns.isMultiple(of: 2)
            ? previewAspectRatio
            : 1 / previewAspectRatio
    }

    nonisolated func resolvingPreviewRect(_ rect: CGRect) -> Self {
        Self(
            framingSnapshot: framingSnapshot,
            previewAspectRatio: previewAspectRatio,
            targetAspectRatio: targetAspectRatio,
            captureToOutputRotationAngle: captureToOutputRotationAngle,
            normalizedPreviewRect: rect
        )
    }
}
