//
//  GetMask.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/23.
//

import Foundation

extension MaskServer {
    func getMask(id: String, locale: String = "zh-Hans") throws -> MaskContent?
    {
        guard let documents = try dataSource.load(id: id, locale: locale) else {
            return nil
        }

        return try MaskContent(documents: documents, locale: locale)
    }
}
