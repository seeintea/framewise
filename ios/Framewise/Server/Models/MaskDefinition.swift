//
//  MaskDefinition.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import Foundation

struct MaskDefinition: Decodable, Equatable, Identifiable, Sendable {
    let schemaVersion: Int
    let id: String
    let defaultVariantId: String
    let variants: [MaskVariant]

    var defaultVariant: MaskVariant? {
        variants.first { $0.id == defaultVariantId }
    }
}

struct MaskVariant: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let aspectRatio: MaskAspectRatio
    let elements: [MaskElement]
    let annotations: [MaskAnnotationAnchor]?
}

struct MaskAspectRatio: Decodable, Equatable, Sendable {
    let width: Double
    let height: Double
}

struct MaskElement: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let type: MaskElementRole
    let shape: MaskShape

    private enum CodingKeys: String, CodingKey {
        case id = "key"
        case type
        case shape
    }
}

enum MaskElementRole: String, Decodable, Equatable, Sendable {
    case subject
    case horizon
    case safeLine = "safe-line"
}

struct MaskAnnotationAnchor: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let position: NormalizedPoint
    let maxWidth: Double?

    private enum CodingKeys: String, CodingKey {
        case id = "key"
        case position
        case maxWidth
    }
}

struct NormalizedPoint: Decodable, Equatable, Sendable {
    let x: Double
    let y: Double
}

struct NormalizedBounds: Decodable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
