//
//  AppRootView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/23.
//

import SwiftUI

private enum AppRoute: Hashable {
    case search
    case camera(CameraMaskRequest)
}

struct AppRootView: View {
    private static let maskServer = MaskServer()
    private static let masks = Result {
        try maskServer.listMasks()
    }

    @State private var path: [AppRoute] = []

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
                    searchDestination()
                case .camera(let request):
                    cameraDestination(for: request)
                }
            }
        }
    }

    @ViewBuilder
    private func searchDestination() -> some View {
        if case .success(let masks) = Self.masks {
            SearchView(
                masks: masks,
                onCameraRequest: { request in
                    path.append(.camera(request))
                }
            )
        } else {
            ContentUnavailableView(
                "无法加载模版",
                systemImage: "square.grid.2x2",
                description: Text("请稍后重试。")
            )
        }
    }

    @ViewBuilder
    private func cameraDestination(for request: CameraMaskRequest) -> some View {
        if let mask = try? Self.maskServer.getMask(id: request.maskId) {
            CameraAccess(
                variant: mask.defaultVariant,
                annotationTextById: mask.annotationTextById(
                    variantId: mask.defaultVariant.id
                )
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
