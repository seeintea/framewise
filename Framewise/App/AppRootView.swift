import SwiftUI

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
                    SearchScreen()
                }
            }
        }
    }
}

private enum AppRoute: Hashable {
    case search
}
