//
//  MainTabView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct MainTabView: View {
    @State private var selection = MainTab.guide

    let onCameraRequest: (CameraMaskRequest) -> Void
    let onSearch: () -> Void
    let onSearchTest: () -> Void

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
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
        case .guide:
            GuideView(onCameraRequest: onCameraRequest)
        case .settings:
            SettingView(onSearchTest: onSearchTest)
        }
    }
}

enum MainTab: Hashable, CaseIterable {
    case guide
    case settings

    var title: LocalizedStringKey {
        switch self {
        case .guide:
            "模版"
        case .settings:
            "设置"
        }
    }

    var imageName: String {
        switch self {
        case .guide:
            "TabGuide"
        case .settings:
            "TabSetting"
        }
    }
}
