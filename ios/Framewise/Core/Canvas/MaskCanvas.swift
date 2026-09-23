//
//  MaskCanvas.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import SwiftUI

struct MaskCanvas: View {
    let variant: MaskVariant
    var annotationTextById: [String: String] = [:]
    var showsAnnotations = true
    var color = Color(
        red: 209.0 / 255.0,
        green: 213.0 / 255.0,
        blue: 220.0 / 255.0
    )
    var lineWidth: CGFloat = 0.5
    var dash: [CGFloat] = [8, 6]

    var body: some View {
        ZStack {
            Canvas { context, size in
                let drawingRect = CGRect(origin: .zero, size: size)

                for element in variant.elements {
                    context.stroke(
                        path(for: element.shape, in: drawingRect),
                        with: .color(color.opacity(0.7)),
                        style: strokeStyle(for: element.shape)
                    )
                }
            }

            GeometryReader { proxy in
                let drawingRect = CGRect(origin: .zero, size: proxy.size)
                let shortSide = min(proxy.size.width, proxy.size.height)
                let fontSize = max(shortSide * 0.035, 7)

                ForEach(variant.annotations ?? []) { annotation in
                    if let text = annotationTextById[annotation.id] {
                        Text(text)
                            .font(.system(size: fontSize, weight: .light))
                            .foregroundStyle(color)
                            .multilineTextAlignment(.center)
                            .frame(
                                width: annotation.maxWidth.map {
                                    CGFloat($0) * proxy.size.width
                                }
                            )
                            .position(
                                CanvasGeometry.point(
                                    annotation.position,
                                    in: drawingRect
                                )
                            )
                    }
                }
            }
            .opacity(showsAnnotations ? 1 : 0)
            .animation(.easeOut(duration: 0.25), value: showsAnnotations)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func path(for shape: MaskShape, in rect: CGRect) -> Path {
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

    private func strokeStyle(for shape: MaskShape) -> StrokeStyle {
        StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round,
            dash: shape.isDashed ? dash : []
        )
    }
}
