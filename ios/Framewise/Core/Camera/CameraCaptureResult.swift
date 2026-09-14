//
//  CameraCaptureResult.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

import Foundation

enum CameraCaptureResult: Sendable {
    case photo(Data)
    case livePhoto(photoData: Data, pairedVideoURL: URL)

    var isLivePhoto: Bool {
        switch self {
        case .photo:
            false
        case .livePhoto:
            true
        }
    }
}
