//
//  CameraScreen.swift
//  Framewise
//
//  Camera feature rewrite entry point.
//

import SwiftUI

struct CameraScreen: View {
    let variant: CompositionTemplateVariant
    let annotationTextById: [String: String]

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ContentUnavailableView(
                "相机开发中",
                systemImage: "camera",
                description: Text("新的相机实现将从这里开始。")
            )
            .foregroundStyle(.white)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
