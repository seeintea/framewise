//
//  FloatingTabBar.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct FloatingTabBar: View {
    @Binding var selection: MainTab
    let onSearch: () -> Void

    @Namespace private var selectionAnimation
    @Namespace private var selectionGlass

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
        .padding(3)
        .tabBarSurface()
    }

    private func tabButton(_ tab: MainTab) -> some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.05)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 1.5) {
                Image(tab.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(tab.title)
                    .font(
                        .system(
                            size: 10,
                            weight: selection == tab ? .semibold : .medium
                        )
                    )
            }
            .foregroundStyle(
                selection == tab ? Color.primary : Color(uiColor: .systemGray)
            )
            .frame(width: 92, height: 50)
            .background {
                if selection == tab {
                    selectionBackground
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.clear.interactive(), in: .capsule)
                .glassEffectID("selection", in: selectionGlass)
                .matchedGeometryEffect(
                    id: "selection",
                    in: selectionAnimation
                )
        } else {
            Capsule()
                .fill(Color(uiColor: .systemGray5))
                .matchedGeometryEffect(
                    id: "selection",
                    in: selectionAnimation
                )
        }
    }

    @ViewBuilder
    private var searchButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: onSearch) {
                searchButtonLabel
                    .frame(width: 42, height: 42)
                    .contentShape(.circle)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("搜索")
        } else {
            Button(action: onSearch) {
                searchButtonLabel
                    .frame(width: 56, height: 56)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .tabBarSurface()
            .accessibilityLabel("搜索")
        }
    }

    private var searchButtonLabel: some View {
        Image("TabSearch")
            .resizable()
            .scaledToFit()
            .frame(width: 29, height: 29)
            .foregroundStyle(Color(uiColor: .systemGray))
    }
}

extension View {
    @ViewBuilder
    fileprivate func tabBarSurface() -> some View {
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
