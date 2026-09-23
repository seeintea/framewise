//
//  MaskDataSource.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/23.
//

import Foundation

struct MaskDataSource {
    struct Documents {
        let id: String
        let mask: Data
        let localization: Data
    }

    enum LoadError: Error {
        case templatesDirectoryNotFound
        case noMasksFound
        case localizationNotFound(maskURL: URL, locale: String)
    }

    private struct MaskIdentity: Decodable {
        let id: String
    }

    private enum Location {
        case bundle(Bundle)
        case directory(URL)
    }

    private let location: Location

    init(bundle: Bundle = .main) {
        location = .bundle(bundle)
    }

    init(templatesDirectory: URL) {
        location = .directory(templatesDirectory)
    }

    func loadAll(locale: String) throws -> [Documents] {
        try maskURLs().map { try loadDocuments(at: $0, locale: locale) }
    }

    func load(id: String, locale: String) throws -> Documents? {
        for url in try maskURLs() {
            let mask = try Data(contentsOf: url)
            let identity = try JSONDecoder().decode(
                MaskIdentity.self,
                from: mask
            )

            if identity.id == id {
                return try loadDocuments(
                    at: url,
                    mask: mask,
                    locale: locale
                )
            }
        }

        return nil
    }

    private func maskURLs() throws -> [URL] {
        let directory: URL
        switch location {
        case .bundle(let bundle):
            guard let url = bundle.url(
                forResource: "templates",
                withExtension: nil
            ) else {
                throw LoadError.templatesDirectoryNotFound
            }
            directory = url
        case .directory(let url):
            directory = url
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            throw LoadError.templatesDirectoryNotFound
        }

        let urls =
            enumerator
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent == "template.v1.json" }
            .sorted { $0.path < $1.path }

        guard !urls.isEmpty else {
            throw LoadError.noMasksFound
        }

        return urls
    }

    private func loadDocuments(at url: URL, locale: String) throws -> Documents
    {
        try loadDocuments(
            at: url,
            mask: Data(contentsOf: url),
            locale: locale
        )
    }

    private func loadDocuments(
        at url: URL,
        mask: Data,
        locale: String
    ) throws -> Documents {
        let id = try JSONDecoder().decode(MaskIdentity.self, from: mask)
            .id
        let localizationURL =
            url
            .deletingLastPathComponent()
            .appendingPathComponent("\(locale).v1.json")

        guard FileManager.default.fileExists(atPath: localizationURL.path)
        else {
            throw LoadError.localizationNotFound(
                maskURL: url,
                locale: locale
            )
        }

        return Documents(
            id: id,
            mask: mask,
            localization: try Data(contentsOf: localizationURL)
        )
    }
}
