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
    @State private var showsCameraSaveError = false

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
        .onReceive(NotificationCenter.default.publisher(for: .cameraPhotoSaveFailed)) { _ in
            showsCameraSaveError = true
        }
        .alert(.cameraErrorTitle, isPresented: $showsCameraSaveError) {
            Button(.cameraErrorOk, role: .cancel) {}
        } message: {
            Text(.cameraErrorSave)
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
        let availableMasks = (try? Self.masks.get()) ?? []
        let maskById = Dictionary(uniqueKeysWithValues: availableMasks.map { ($0.id, $0) })
        let requestedIds = request.relatedMaskIds.contains(request.maskId)
            ? request.relatedMaskIds : [request.maskId] + request.relatedMaskIds
        let orderedIds = requestedIds.reduce(into: [String]()) { ids, id in
            if !ids.contains(id) { ids.append(id) }
        }
        let masks = maskById[request.maskId] == nil
            ? [] : orderedIds.compactMap { maskById[$0] }

        CameraAccess(masks: masks, initialMaskId: request.maskId)
    }
}
