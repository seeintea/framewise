//
//  CameraTemplateRequest.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import Foundation

struct CameraTemplateRequest: Hashable {
    let templateIds: [String]
    let initialTemplateId: String
}
