//
//  FramewiseApp.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/11.
//

import SwiftUI

@main
struct FramewiseApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

private enum AppRoute: Hashable {
    case search
    case camera(CameraTemplateRequest)
}

struct AppRootView: View {
    private static let compositionCatalog = Result {
        try CompositionCatalog()
    }

    @State private var path: [AppRoute] = []
    @AppStorage(AppSettingKey.showsCameraAnnotationsOnEntry)
    private var showsCameraAnnotationsOnEntry = true

    var body: some View {
        NavigationStack(path: $path) {
            MainTabView(
                onCameraRequest: { request in
                    path.append(.camera(request))
                },
                onSearch: {
                    path.append(.search)
                }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .search:
                    SearchView()
                case .camera(let request):
                    cameraDestination(for: request)
                }
            }
        }
    }

    @ViewBuilder
    private func cameraDestination(for request: CameraTemplateRequest) -> some View {
        if case .success(let catalog) = Self.compositionCatalog,
           request.templateIds.contains(request.initialTemplateId),
           let template = catalog.template(id: request.initialTemplateId),
           let variant = template.defaultVariant {
            CameraScreen(
                variant: variant,
                annotationTextById: catalog.annotationTextById(
                    templateId: template.id,
                    variantId: variant.id
                ),
                showsAnnotationsOnEntry: showsCameraAnnotationsOnEntry
            )
        } else {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                Text("无法加载构图模版")
                    .foregroundStyle(.white)
            }
        }
    }
}
