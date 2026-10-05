//
//  SettingsView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct SettingView: View {
    var body: some View {
        Form {
            #if DEBUG
                Section("开发调试") {
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

                    NavigationLink {
                        CameraUIDesignPreview()
                    } label: {
                        Label("相机 UI 对比 · 新设计", systemImage: "camera.aperture")
                    }
                }
            #endif
        }
    }
}
