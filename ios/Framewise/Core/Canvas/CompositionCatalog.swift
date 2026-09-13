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

    init(bundle: Bundle = .main) throws {
        guard let templatesDirectory = bundle.url(
            forResource: "templates",
            withExtension: nil
        ) else {
            throw CompositionCatalogError.templatesDirectoryNotFound
        }

        try self.init(templatesDirectory: templatesDirectory)
    }

    init(templatesDirectory: URL) throws {
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
    }

    func template(id: String) -> CompositionTemplate? {
        templatesById[id]
    }
}

enum CompositionCatalogError: Error, Equatable {
    case templatesDirectoryNotFound
    case noTemplatesFound
    case unsupportedSchemaVersion(Int, templateId: String)
    case defaultVariantNotFound(templateId: String, variantId: String)
    case duplicateTemplateId(String)
}

enum CompositionTemplateIdentifier {
    static let classicRuleOfThirds = "b6fb0923-8f41-420c-a403-c21be035065e"
}
