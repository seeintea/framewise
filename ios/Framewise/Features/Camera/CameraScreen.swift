//
//  CameraScreen.swift
//  Framewise
//
//  Created by Codex on 2026/9/13.
//

import SwiftUI

struct CameraScreen: View {
    let variant: CompositionTemplateVariant
    let annotationTextById: [String: String]

    @State private var areAnnotationsVisible: Bool

    init(
        variant: CompositionTemplateVariant,
        annotationTextById: [String: String],
        showsAnnotationsOnEntry: Bool
    ) {
        self.variant = variant
        self.annotationTextById = annotationTextById
        _areAnnotationsVisible = State(
            initialValue: showsAnnotationsOnEntry
        )
    }

    var body: some View {
        CameraView(
            variant: variant,
            annotationTextById: annotationTextById,
            areAnnotationsVisible: $areAnnotationsVisible
        )
    }
}
