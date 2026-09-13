//
//  CameraView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import SwiftUI

struct CameraView: View {
    let variant: CompositionTemplateVariant
    var annotationTextById: [String: String] = [:]
    @Binding var areAnnotationsVisible: Bool

    @State private var didControlAnnotationVisibility = false
    @State private var isFlashEnabled = false
    @State private var isFrontFacing = false
    @State private var selectedZoom = 1.0

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = canvasSize(in: proxy.size)
            let previewSize = previewSize(for: canvasSize)

            ZStack {
                Color.black

                ZStack {
                    Color(
                        red: 36.0 / 255.0,
                        green: 36.0 / 255.0,
                        blue: 39.0 / 255.0
                    )

                    CompositionCanvas(
                        variant: variant,
                        annotationTextById: annotationTextById,
                        showsAnnotations: areAnnotationsVisible
                    )
                    .frame(
                        width: canvasSize.width,
                        height: canvasSize.height
                    )
                    .rotationEffect(isLandscape ? .degrees(90) : .zero)
                }
                .frame(width: previewSize.width, height: previewSize.height)
                .overlay(alignment: .bottom) {
                    CameraZoomControls(selectedZoom: $selectedZoom)
                        .padding(.bottom, 16)
                }
                .clipped()
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            CameraCaptureControls(
                isFrontFacing: $isFrontFacing
            )
            .padding(.horizontal, 24)
            .safeAreaPadding(.bottom, 18)
        }
        .toolbar {
            CameraTopControls(
                isFlashEnabled: $isFlashEnabled,
                areAnnotationsVisible: $areAnnotationsVisible
            )
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            guard areAnnotationsVisible else {
                return
            }

            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }

            guard !didControlAnnotationVisibility else {
                return
            }

            areAnnotationsVisible = false
        }
        .onChange(of: areAnnotationsVisible) { _, _ in
            didControlAnnotationVisibility = true
        }
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
                height: shortSide
                    * CGFloat(aspectRatio.height / aspectRatio.width)
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

#Preview {
    @Previewable @State var areAnnotationsVisible = true

    if let catalog = try? CompositionCatalog(),
        let template = catalog.template(
            id: "34e35f2a-0222-4a35-a97a-d11e6281c2fd"
        ),
        let variant = template.defaultVariant
    {
        CameraView(
            variant: variant,
            annotationTextById: catalog.annotationTextById(
                templateId: template.id,
                variantId: variant.id
            ),
            areAnnotationsVisible: $areAnnotationsVisible
        )
    } else {
        ContentUnavailableView(
            "无法加载构图模版",
            systemImage: "camera"
        )
    }
}
