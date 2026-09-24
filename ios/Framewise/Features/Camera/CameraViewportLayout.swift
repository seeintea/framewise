//
//  CameraViewportLayout.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import SwiftUI

struct CameraViewportLayout {
    let previewSize: CGSize
    let maskDrawingSize: CGSize
    let maskRotation: Angle

    init(aspectRatio: MaskAspectRatio, availableSize: CGSize) {
        let templateWidth = CGFloat(aspectRatio.width)
        let templateHeight = CGFloat(aspectRatio.height)
        let portraitRatio =
            min(templateWidth, templateHeight)
            / max(templateWidth, templateHeight)
        let previewWidth = min(
            availableSize.width,
            availableSize.height * portraitRatio
        )
        let previewHeight = previewWidth / portraitRatio

        previewSize = CGSize(width: previewWidth, height: previewHeight)
        if templateWidth > templateHeight {
            maskDrawingSize = CGSize(
                width: previewHeight,
                height: previewWidth
            )
            maskRotation = .degrees(90)
        } else {
            maskDrawingSize = previewSize
            maskRotation = .zero
        }
    }
}
