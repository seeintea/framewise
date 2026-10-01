//
//  SettingsView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct SettingView: View {
    let onSearchTest: () -> Void

    var body: some View {
        Form {
            #if DEBUG
                Section("开发调试") {
                    Button(action: onSearchTest) {
                        Label("SearchTest", systemImage: "rectangle.grid.2x2")
                    }

                    NavigationLink {
                        PermissionDebugView()
                    } label: {
                        Label("权限测试", systemImage: "lock.shield")
                    }

                    NavigationLink {
                        CameraDebugView()
                    } label: {
                        Label("相机预览 · 多模版", systemImage: "camera.viewfinder")
                    }

                    NavigationLink {
                        CameraDebugView(showsRelatedMasks: false)
                    } label: {
                        Label("相机预览 · 单模版", systemImage: "camera")
                    }
                }
            #endif
        }
    }
}
