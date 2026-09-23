//
//  MaskLocalization.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import Foundation

struct MaskLocalization: Decodable, Equatable, Sendable {
    let schemaVersion: Int
    let locale: String
    let maskId: String
    let title: String
    let description: String
    let variants: [MaskVariantLocalization]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case locale
        case maskId = "templateId"
        case title
        case description
        case variants
    }
}

struct MaskVariantLocalization: Decodable, Equatable, Sendable {
    let variantId: String
    let instruction: String
    let annotations: [String: String]?
}
