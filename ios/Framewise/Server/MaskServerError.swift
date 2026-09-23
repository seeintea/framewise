//
//  MaskServerError.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import Foundation

enum MaskServerError: Error, Equatable {
    case unsupportedSchemaVersion(Int, maskId: String)
    case defaultVariantNotFound(maskId: String, variantId: String)
    case duplicateMaskId(String)
    case unsupportedLocalizationSchemaVersion(Int, maskId: String)
    case localizationLocaleMismatch(
        expected: String,
        actual: String,
        maskId: String
    )
    case localizationMaskIdMismatch(maskId: String, localizationMaskId: String)
    case duplicateVariantLocalization(maskId: String, variantId: String)
    case localizationVariantMismatch(maskId: String)
    case variantLocalizationNotFound(maskId: String, variantId: String)
    case annotationLocalizationNotFound(
        maskId: String,
        variantId: String,
        annotationId: String
    )
}
