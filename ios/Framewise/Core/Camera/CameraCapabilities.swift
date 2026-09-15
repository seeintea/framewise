//
//  CameraCapabilities.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

import Foundation

enum CameraPosition: Equatable, Sendable {
    case back
    case front
}

struct CameraCapabilities: Sendable {
    let position: CameraPosition
    let canSwitchCamera: Bool
    let zoomFactors: [Double]
    let selectedZoomFactor: Double
    let minimumZoomFactor: Double
    let maximumZoomFactor: Double
    let isFlashAvailable: Bool
    let isFocusPointAvailable: Bool
    let minimumExposureBias: Double
    let maximumExposureBias: Double
    let selectedExposureBias: Double

    var isExposureBiasAvailable: Bool {
        maximumExposureBias - minimumExposureBias >= 0.1
    }

    nonisolated static let unavailable = CameraCapabilities(
        position: .back,
        canSwitchCamera: false,
        zoomFactors: [],
        selectedZoomFactor: 1,
        minimumZoomFactor: 1,
        maximumZoomFactor: 1,
        isFlashAvailable: false,
        isFocusPointAvailable: false,
        minimumExposureBias: 0,
        maximumExposureBias: 0,
        selectedExposureBias: 0
    )
}
