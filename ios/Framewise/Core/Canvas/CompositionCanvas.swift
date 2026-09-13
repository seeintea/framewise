//
//  CompositionCanvas.swift
//  Framewise
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

#Preview("Composition canvas") {
    ZStack {
        Color.black

        CompositionCanvas(variant: .canvasPreview)
    }
    .frame(width: 300, height: 400)
}

private extension CompositionTemplateVariant {
    static let canvasPreview = CompositionTemplateVariant(
        id: "canvas-preview-3x4",
        aspectRatio: CompositionAspectRatio(width: 3, height: 4),
        elements: [
            CompositionElement(
                id: "horizon",
                type: .horizon,
                shape: .line(
                    start: NormalizedPoint(x: 0.08, y: 0.66),
                    end: NormalizedPoint(x: 0.92, y: 0.66)
                )
            ),
            CompositionElement(
                id: "axis",
                type: .safeLine,
                shape: .dashedLine(
                    start: NormalizedPoint(x: 0.5, y: 0.1),
                    end: NormalizedPoint(x: 0.5, y: 0.9)
                )
            ),
            CompositionElement(
                id: "subject-anchor",
                type: .subject,
                shape: .dashedCircle(
                    center: NormalizedPoint(x: 0.5, y: 0.36),
                    radius: 0.08
                )
            ),
            CompositionElement(
                id: "vanishing-point",
                type: .subject,
                shape: .circle(
                    center: NormalizedPoint(x: 0.5, y: 0.66),
                    radius: 0.02
                )
            ),
            CompositionElement(
                id: "subject-area",
                type: .subject,
                shape: .rect(
                    bounds: NormalizedBounds(
                        x: 0.28,
                        y: 0.2,
                        width: 0.44,
                        height: 0.66
                    ),
                    cornerRadius: 0.03
                )
            )
        ],
        annotations: nil
    )
}
