//
//  ListMasks.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/23.
//

import Foundation

extension MaskServer {
    func listMasks(locale: String = "zh-Hans") throws -> [MaskContent] {
        let masks = try dataSource.loadAll(locale: locale).map {
            try MaskContent(documents: $0, locale: locale)
        }

        var seenIds: Set<String> = []
        for mask in masks {
            guard seenIds.insert(mask.id).inserted else {
                throw MaskServerError.duplicateMaskId(mask.id)
            }
        }

        return masks
    }
}
