//
//  SettingsView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct SettingView: View {
    @AppStorage(AppSettingKey.showsCameraAnnotationsOnEntry)
    private var showsCameraAnnotationsOnEntry = true

    var body: some View {
        Form {
            Section {
                Toggle(
                    "进入相机时显示构图提示",
                    isOn: $showsCameraAnnotationsOnEntry
                )
            } footer: {
                Text("开启后，进入相机时会显示构图提示，并在 3 秒后自动隐藏。")
            }

            Section("开发") {
                NavigationLink {
                    CameraDebugView()
                } label: {
                    Label("Camera Debug", systemImage: "camera.viewfinder")
                }
            }
        }
    }
}

enum AppSettingKey {
    static let showsCameraAnnotationsOnEntry =
        "camera.showsAnnotationsOnEntry"
    static let isLivePhotoEnabled = "camera.isLivePhotoEnabled"
}
