//
//  CameraMaskRequest.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import Foundation

struct CameraMaskRequest: Hashable {
    let maskId: String
    let relatedMaskIds: [String]
}
