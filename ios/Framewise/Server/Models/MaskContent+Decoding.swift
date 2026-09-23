//
//  MaskContent+Decoding.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import Foundation

extension MaskContent {
    init(documents: MaskDataSource.Documents, locale: String) throws {
        let decoder = JSONDecoder()
        let definition = try decoder.decode(
            MaskDefinition.self,
            from: documents.mask
        )

        guard definition.schemaVersion == 1 else {
            throw MaskServerError.unsupportedSchemaVersion(
                definition.schemaVersion,
                maskId: definition.id
            )
        }

        guard let defaultVariant = definition.defaultVariant else {
            throw MaskServerError.defaultVariantNotFound(
                maskId: definition.id,
                variantId: definition.defaultVariantId
            )
        }

        let localization = try decoder.decode(
            MaskLocalization.self,
            from: documents.localization
        )

        guard localization.schemaVersion == 1 else {
            throw MaskServerError.unsupportedLocalizationSchemaVersion(
                localization.schemaVersion,
                maskId: definition.id
            )
        }

        guard localization.locale == locale else {
            throw MaskServerError.localizationLocaleMismatch(
                expected: locale,
                actual: localization.locale,
                maskId: definition.id
            )
        }

        guard localization.maskId == definition.id else {
            throw MaskServerError.localizationMaskIdMismatch(
                maskId: definition.id,
                localizationMaskId: localization.maskId
            )
        }

        var localizationByVariantId: [String: MaskVariantLocalization] =
            [:]
        for variantLocalization in localization.variants {
            guard
                localizationByVariantId.updateValue(
                    variantLocalization,
                    forKey: variantLocalization.variantId
                ) == nil
            else {
                throw MaskServerError.duplicateVariantLocalization(
                    maskId: definition.id,
                    variantId: variantLocalization.variantId
                )
            }
        }

        guard localizationByVariantId.count == definition.variants.count else {
            throw MaskServerError.localizationVariantMismatch(
                maskId: definition.id
            )
        }

        for variant in definition.variants {
            guard let variantLocalization = localizationByVariantId[variant.id]
            else {
                throw MaskServerError.variantLocalizationNotFound(
                    maskId: definition.id,
                    variantId: variant.id
                )
            }

            for annotation in variant.annotations ?? [] {
                guard
                    let text = variantLocalization.annotations?[annotation.id],
                    !text.isEmpty
                else {
                    throw MaskServerError.annotationLocalizationNotFound(
                        maskId: definition.id,
                        variantId: variant.id,
                        annotationId: annotation.id
                    )
                }
            }
        }

        self.definition = definition
        self.localization = localization
        self.defaultVariant = defaultVariant
    }
}
