//
//  CanvasGeometry.swift
//  Framewise
//

import CoreGraphics

enum CanvasGeometry {
    static func point(_ point: NormalizedPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + CGFloat(point.x) * rect.width,
            y: rect.minY + CGFloat(point.y) * rect.height
        )
    }

    static func bounds(_ bounds: NormalizedBounds, in rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX + CGFloat(bounds.x) * rect.width,
            y: rect.minY + CGFloat(bounds.y) * rect.height,
            width: CGFloat(bounds.width) * rect.width,
            height: CGFloat(bounds.height) * rect.height
        )
    }

    static func length(_ length: Double, in rect: CGRect) -> CGFloat {
        CGFloat(length) * min(rect.width, rect.height)
    }
}
