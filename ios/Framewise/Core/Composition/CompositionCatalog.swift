//
//  CompositionCatalog.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import Foundation

struct CompositionCatalog: Sendable {
    let templates: [CompositionTemplate]

    private let templatesById: [String: CompositionTemplate]
    private let localizationsByTemplateId: [String: CompositionTemplateLocalization]

    init(bundle: Bundle = .main, locale: String = "zh-Hans") throws {
        guard let templatesDirectory = bundle.url(
            forResource: "templates",
            withExtension: nil
        ) else {
            throw CompositionCatalogError.templatesDirectoryNotFound
        }

        try self.init(templatesDirectory: templatesDirectory, locale: locale)
    }

    init(templatesDirectory: URL, locale: String = "zh-Hans") throws {
        guard let enumerator = FileManager.default.enumerator(
            at: templatesDirectory,
            includingPropertiesForKeys: nil
        ) else {
            throw CompositionCatalogError.templatesDirectoryNotFound
        }

        let templateURLs = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent == "template.v1.json" }
            .sorted { $0.path < $1.path }

        guard !templateURLs.isEmpty else {
            throw CompositionCatalogError.noTemplatesFound
        }

        let decoder = JSONDecoder()
        var localizationsByTemplateId: [String: CompositionTemplateLocalization] = [:]
        let templates = try templateURLs.map { url in
            let template = try decoder.decode(
                CompositionTemplate.self,
                from: Data(contentsOf: url)
            )

            guard template.schemaVersion == 1 else {
                throw CompositionCatalogError.unsupportedSchemaVersion(
                    template.schemaVersion,
                    templateId: template.id
                )
            }

            guard template.defaultVariant != nil else {
                throw CompositionCatalogError.defaultVariantNotFound(
                    templateId: template.id,
                    variantId: template.defaultVariantId
                )
            }

            let localizationURL = url
                .deletingLastPathComponent()
                .appendingPathComponent("\(locale).v1.json")

            guard FileManager.default.fileExists(atPath: localizationURL.path) else {
                throw CompositionCatalogError.localizationNotFound(
                    locale: locale,
                    templateId: template.id
                )
            }

            let localization = try decoder.decode(
                CompositionTemplateLocalization.self,
                from: Data(contentsOf: localizationURL)
            )

            guard localization.schemaVersion == 1 else {
                throw CompositionCatalogError.unsupportedLocalizationSchemaVersion(
                    localization.schemaVersion,
                    templateId: template.id
                )
            }

            guard localization.locale == locale else {
                throw CompositionCatalogError.localizationLocaleMismatch(
                    expected: locale,
                    actual: localization.locale,
                    templateId: template.id
                )
            }

            guard localization.templateId == template.id else {
                throw CompositionCatalogError.localizationTemplateMismatch(
                    templateId: template.id,
                    localizationTemplateId: localization.templateId
                )
            }

            var localizationByVariantId: [String: CompositionVariantLocalization] = [:]

            for variantLocalization in localization.variants {
                guard localizationByVariantId.updateValue(
                    variantLocalization,
                    forKey: variantLocalization.variantId
                ) == nil else {
                    throw CompositionCatalogError.duplicateVariantLocalization(
                        templateId: template.id,
                        variantId: variantLocalization.variantId
                    )
                }
            }

            guard localizationByVariantId.count == template.variants.count else {
                throw CompositionCatalogError.localizationVariantMismatch(
                    templateId: template.id
                )
            }

            for variant in template.variants {
                guard let variantLocalization = localizationByVariantId[variant.id] else {
                    throw CompositionCatalogError.variantLocalizationNotFound(
                        templateId: template.id,
                        variantId: variant.id
                    )
                }

                for annotation in variant.annotations ?? [] {
                    guard let text = variantLocalization.annotations?[annotation.id],
                          !text.isEmpty else {
                        throw CompositionCatalogError.annotationLocalizationNotFound(
                            templateId: template.id,
                            variantId: variant.id,
                            annotationId: annotation.id
                        )
                    }
                }
            }

            localizationsByTemplateId[template.id] = localization

            return template
        }

        var templatesById: [String: CompositionTemplate] = [:]

        for template in templates {
            guard templatesById.updateValue(template, forKey: template.id) == nil else {
                throw CompositionCatalogError.duplicateTemplateId(template.id)
            }
        }

        self.templates = templates
        self.templatesById = templatesById
        self.localizationsByTemplateId = localizationsByTemplateId
    }

    func template(id: String) -> CompositionTemplate? {
        templatesById[id]
    }

    func localization(templateId: String) -> CompositionTemplateLocalization? {
        localizationsByTemplateId[templateId]
    }

    func annotationTextById(
        templateId: String,
        variantId: String
    ) -> [String: String] {
        localizationsByTemplateId[templateId]?
            .variants
            .first { $0.variantId == variantId }?
            .annotations ?? [:]
    }
}

enum CompositionCatalogError: Error, Equatable {
    case templatesDirectoryNotFound
    case noTemplatesFound
    case unsupportedSchemaVersion(Int, templateId: String)
    case defaultVariantNotFound(templateId: String, variantId: String)
    case duplicateTemplateId(String)
    case localizationNotFound(locale: String, templateId: String)
    case unsupportedLocalizationSchemaVersion(Int, templateId: String)
    case localizationLocaleMismatch(
        expected: String,
        actual: String,
        templateId: String
    )
    case localizationTemplateMismatch(
        templateId: String,
        localizationTemplateId: String
    )
    case localizationVariantMismatch(templateId: String)
    case duplicateVariantLocalization(templateId: String, variantId: String)
    case variantLocalizationNotFound(templateId: String, variantId: String)
    case annotationLocalizationNotFound(
        templateId: String,
        variantId: String,
        annotationId: String
    )
}
