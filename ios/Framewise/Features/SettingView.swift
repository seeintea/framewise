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
            }
#endif
        }
    }
}
