//
//  CameraMaskOverlay.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/24.
//

import SwiftUI

struct CameraMaskOverlay: View {
    let variant: MaskVariant
    let annotationTextById: [String: String]
    let showsAnnotations: Bool
    let layout: CameraViewportLayout

    var body: some View {
        MaskCanvas(
            variant: variant,
            annotationTextById: annotationTextById,
            showsAnnotations: showsAnnotations
        )
        .frame(
            width: layout.maskDrawingSize.width,
            height: layout.maskDrawingSize.height
        )
        .rotationEffect(layout.maskRotation)
        .frame(width: layout.previewSize.width, height: layout.previewSize.height)
    }
}
