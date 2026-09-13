//
//  CompositionTemplate.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import Foundation

struct CompositionTemplate: Decodable, Equatable, Identifiable, Sendable {
    let schemaVersion: Int
    let id: String
    let key: String
    let defaultVariantId: String
    let variants: [CompositionTemplateVariant]

    var defaultVariant: CompositionTemplateVariant? {
        variants.first { $0.id == defaultVariantId }
    }
}

struct CompositionTemplateVariant: Decodable, Equatable, Identifiable, Sendable
{
    let id: String
    let key: String
    let aspectRatio: CompositionAspectRatio
    let elements: [CompositionElement]
    let annotations: [CompositionAnnotationAnchor]?
}

struct CompositionAspectRatio: Decodable, Equatable, Sendable {
    let width: Double
    let height: Double
}

struct CompositionElement: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let type: CompositionElementRole
    let shape: CompositionShape

    private enum CodingKeys: String, CodingKey {
        case id = "key"
        case type
        case shape
    }
}

enum CompositionElementRole: String, Decodable, Equatable, Sendable {
    case subject
    case horizon
    case safeLine = "safe-line"
}

struct CompositionAnnotationAnchor: Decodable, Equatable, Identifiable, Sendable
{
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
