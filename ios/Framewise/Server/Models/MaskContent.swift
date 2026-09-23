//
//  MaskContent.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/23.
//

import Foundation

struct MaskContent: Identifiable, Sendable {
    let definition: MaskDefinition
    let localization: MaskLocalization
    let defaultVariant: MaskVariant

    var id: String { definition.id }

    func annotationTextById(variantId: String) -> [String: String] {
        localization.variants
            .first { $0.variantId == variantId }?
            .annotations ?? [:]
    }
}
