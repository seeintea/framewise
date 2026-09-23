//
//  MaskShape.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import Foundation

enum MaskShape: Equatable, Sendable {
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
