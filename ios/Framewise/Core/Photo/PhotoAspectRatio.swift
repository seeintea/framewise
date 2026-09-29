//
//  PhotoAspectRatio.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import CoreGraphics

enum PhotoAspectRatio: String, CaseIterable, Identifiable, Sendable {
    case square = "1:1"
    case standard = "3:4"
    case standardLandscape = "4:3"
    case tall = "9:16"
    case tallLandscape = "16:9"

    var id: String { rawValue }

    nonisolated var dimensions: (width: Int, height: Int) {
        switch self {
        case .square: (1, 1)
        case .standard, .standardLandscape: (3, 4)
        case .tall, .tallLandscape: (9, 16)
        }
    }

    nonisolated var isLandscapeOutput: Bool {
        self == .standardLandscape || self == .tallLandscape
    }

    nonisolated var value: CGFloat {
        CGFloat(dimensions.width) / CGFloat(dimensions.height)
    }
}
