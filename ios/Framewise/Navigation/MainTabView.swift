//
//  MainTabView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct MainTabView: View {
    @State private var selection = MainTab.guides

    let onSearch: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $selection, onSearch: onSearch)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .guides:
            GuidesView()
        case .settings:
            SettingsView()
        }
    }
}

enum MainTab: Hashable, CaseIterable {
    case guides
    case settings

    var title: LocalizedStringKey {
        switch self {
        case .guides:
            "模版"
        case .settings:
            "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .guides:
            "rectangle.on.rectangle"
        case .settings:
            "hand.thumbsup"
        }
    }
}
