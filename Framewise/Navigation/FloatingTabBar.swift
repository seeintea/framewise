import SwiftUI

struct FloatingTabBar: View {
    @Binding var selection: MainTab
    let onSearch: () -> Void

    @Namespace private var selectionAnimation

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    controls
                }
            } else {
                controls
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            tabs
            Spacer(minLength: 0)
            searchButton
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .tabBarSurface()
    }

    private func tabButton(_ tab: MainTab) -> some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.05)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 1.5) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: .regular))
                Text(tab.title)
                    .font(.system(size: 10, weight: selection == tab ? .semibold : .medium))
            }
            .foregroundStyle(selection == tab ? Color.primary : Color(uiColor: .systemGray))
            .frame(width: 92, height: 50)
            .background {
                if selection == tab {
                    Capsule()
                        .fill(Color(uiColor: .systemGray5))
                        .matchedGeometryEffect(id: "selection", in: selectionAnimation)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    private var searchButton: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 29, weight: .light))
                .foregroundStyle(Color(uiColor: .systemGray))
                .frame(width: 56, height: 56)
                .contentShape(.circle)
        }
        .buttonStyle(SearchButtonStyle())
        .tabBarSurface()
        .accessibilityLabel("搜索")
    }
}

private struct SearchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    Circle().fill(Color(uiColor: .systemGray5))
                        .padding(4)
                }
            }
            .foregroundStyle(configuration.isPressed ? Color.primary : Color(uiColor: .systemGray))
    }
}

private extension View {
    @ViewBuilder
    func tabBarSurface() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: .capsule)
        } else {
            background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}
