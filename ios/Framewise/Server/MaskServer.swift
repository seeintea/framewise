//
//  MaskServer.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/23.
//

import Foundation

struct MaskServer {
    let dataSource: MaskDataSource

    init(dataSource: MaskDataSource = MaskDataSource()) {
        self.dataSource = dataSource
    }
}
