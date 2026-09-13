//
//  CompositionShape.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import Foundation

enum CompositionShape: Equatable, Sendable {
    case line(start: NormalizedPoint, end: NormalizedPoint)
    case dashedLine(start: NormalizedPoint, end: NormalizedPoint)
    case dashedCircle(center: NormalizedPoint, radius: Double)
    case circle(center: NormalizedPoint, radius: Double)
    case rect(bounds: NormalizedBounds, cornerRadius: Double?)

    var isDashed: Bool {
        switch self {
        case .dashedLine, .dashedCircle:
            true
        case .line, .circle, .rect:
            false
        }
    }
}

extension CompositionShape: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case start
        case end
        case center
        case radius
        case bounds
        case cornerRadius
    }

    private enum Kind: String, Decodable {
        case line
        case dashedLine = "dashed-line"
        case dashedCircle = "dashed-circle"
        case circle
        case rect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(Kind.self, forKey: .type) {
        case .line:
            self = try .line(
                start: container.decode(NormalizedPoint.self, forKey: .start),
                end: container.decode(NormalizedPoint.self, forKey: .end)
            )
        case .dashedLine:
            self = try .dashedLine(
                start: container.decode(NormalizedPoint.self, forKey: .start),
                end: container.decode(NormalizedPoint.self, forKey: .end)
            )
        case .dashedCircle:
            self = try .dashedCircle(
                center: container.decode(NormalizedPoint.self, forKey: .center),
                radius: container.decode(Double.self, forKey: .radius)
            )
        case .circle:
            self = try .circle(
                center: container.decode(NormalizedPoint.self, forKey: .center),
                radius: container.decode(Double.self, forKey: .radius)
            )
        case .rect:
            self = try .rect(
                bounds: container.decode(NormalizedBounds.self, forKey: .bounds),
                cornerRadius: container.decodeIfPresent(
                    Double.self,
                    forKey: .cornerRadius
                )
            )
        }
    }
}
