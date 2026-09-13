//
//  CompositionCanvas.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import SwiftUI

struct CompositionCanvas: View {
    let variant: CompositionTemplateVariant
    var color = Color(red: 1, green: 212.0 / 255.0, blue: 0)
    var lineWidth: CGFloat = 0.5
    var dash: [CGFloat] = [8, 6]

    var body: some View {
        Canvas { context, size in
            let drawingRect = CGRect(origin: .zero, size: size)

            for element in variant.elements {
                context.stroke(
                    path(for: element.shape, in: drawingRect),
                    with: .color(color),
                    style: strokeStyle(for: element.shape)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func path(for shape: CompositionShape, in rect: CGRect) -> Path {
        switch shape {
        case .line(let start, let end), .dashedLine(let start, let end):
            var path = Path()
            path.move(to: CanvasGeometry.point(start, in: rect))
            path.addLine(to: CanvasGeometry.point(end, in: rect))
            return path

        case .circle(let center, let radius),
            .dashedCircle(let center, let radius):
            let resolvedCenter = CanvasGeometry.point(center, in: rect)
            let resolvedRadius = CanvasGeometry.length(radius, in: rect)
            return Path(
                ellipseIn: CGRect(
                    x: resolvedCenter.x - resolvedRadius,
                    y: resolvedCenter.y - resolvedRadius,
                    width: resolvedRadius * 2,
                    height: resolvedRadius * 2
                )
            )

        case .rect(let bounds, let cornerRadius):
            return RoundedRectangle(
                cornerRadius: CanvasGeometry.length(
                    cornerRadius ?? 0,
                    in: rect
                ),
                style: .continuous
            )
            .path(in: CanvasGeometry.bounds(bounds, in: rect))
        }
    }

    private func strokeStyle(for shape: CompositionShape) -> StrokeStyle {
        StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round,
            dash: shape.isDashed ? dash : []
        )
    }
}
