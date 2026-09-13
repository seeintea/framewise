//
//  CameraView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import SwiftUI

struct CameraView: View {
    let variant: CompositionTemplateVariant

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = canvasSize(in: proxy.size)
            let previewSize = previewSize(for: canvasSize)

            ZStack {
                Color.black

                ZStack {
                    Color(red: 36.0 / 255.0, green: 36.0 / 255.0, blue: 39.0 / 255.0)

                    CompositionCanvas(variant: variant)
                        .frame(
                            width: canvasSize.width,
                            height: canvasSize.height
                        )
                        .rotationEffect(isLandscape ? .degrees(90) : .zero)
                }
                .frame(width: previewSize.width, height: previewSize.height)
                .clipped()
            }
        }
        .ignoresSafeArea()
    }

    private var isLandscape: Bool {
        variant.aspectRatio.width > variant.aspectRatio.height
    }

    private func canvasSize(in availableSize: CGSize) -> CGSize {
        let shortSide = min(availableSize.width, availableSize.height)
        let aspectRatio = variant.aspectRatio

        if aspectRatio.width <= aspectRatio.height {
            return CGSize(
                width: shortSide,
                height: shortSide * CGFloat(aspectRatio.height / aspectRatio.width)
            )
        }

        return CGSize(
            width: shortSide * CGFloat(aspectRatio.width / aspectRatio.height),
            height: shortSide
        )
    }

    private func previewSize(for canvasSize: CGSize) -> CGSize {
        guard isLandscape else {
            return canvasSize
        }

        return CGSize(width: canvasSize.height, height: canvasSize.width)
    }
}
