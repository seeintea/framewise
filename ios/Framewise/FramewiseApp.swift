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
}

struct AppRootView: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MainTabView {
                path.append(.search)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .search:
                    SearchView()
                }
            }
        }
    }
}
