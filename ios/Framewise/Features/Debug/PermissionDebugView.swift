//
//  PermissionDebugView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/21.
//

#if DEBUG
import SwiftUI

struct PermissionDebugView: View {
    private static let testPermissions: [Permissions.Kind] = [
        .camera,
        .photoLibraryAdd,
        .photoLibraryRead,
        .microphone,
    ]

    @Environment(\.scenePhase) private var scenePhase

    @State private var checkResult = Permissions.check([])
    @State private var requestingPermission: Permissions.Kind?

    var body: some View {
        List {
            Section {
                permissionRow(
                    "相机",
                    detail: "拍摄照片的必要权限",
                    permission: .camera,
                    status: status(for: .camera)
                )
                permissionRow(
                    "相册添加",
                    detail: "把拍摄结果保存到系统相册",
                    permission: .photoLibraryAdd,
                    status: status(for: .photoLibraryAdd)
                )
                permissionRow(
                    "相册读取",
                    detail: "用于显示最近照片缩略图，可选",
                    permission: .photoLibraryRead,
                    status: status(for: .photoLibraryRead)
                )
                permissionRow(
                    "麦克风",
                    detail: "用于带声音的实况照片",
                    permission: .microphone,
                    status: status(for: .microphone)
                )
            } footer: {
                Text("每项权限独立检查和申请。已经拒绝的权限需要在系统设置中修改。")
            }
        }
        .navigationTitle("权限测试")
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("系统设置", systemImage: "gearshape") {
                    Task {
                        await Permissions.openSettings()
                    }
                }
            }
        }
        .task {
            reloadStatuses()
        }
        .refreshable {
            reloadStatuses()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            reloadStatuses()
        }
    }

    private func permissionRow(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey,
        permission: Permissions.Kind,
        status: PermissionStatus
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(statusTitle(for: status))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor(for: status))
            }

            Button {
                request(permission)
            } label: {
                if requestingPermission == permission {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("请求中")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("请求权限")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(
                requestingPermission != nil || status != .notDetermined
            )
        }
        .padding(.vertical, 4)
    }

    private func request(_ permission: Permissions.Kind) {
        guard requestingPermission == nil else { return }
        requestingPermission = permission

        Task {
            _ = await Permissions.request([permission])
            reloadStatuses()
            requestingPermission = nil
        }
    }

    private func reloadStatuses() {
        checkResult = Permissions.check(Self.testPermissions)
    }

    private func status(for permission: Permissions.Kind) -> PermissionStatus {
        checkResult[permission]
    }

    private func statusTitle(
        for status: PermissionStatus
    ) -> LocalizedStringKey {
        switch status {
        case .notDetermined:
            "未请求"
        case .authorized:
            "已授权"
        case .limited:
            "有限访问"
        case .denied:
            "已拒绝"
        case .restricted:
            "受限制"
        case .unknown:
            "未知"
        }
    }

    private func statusColor(for status: PermissionStatus) -> Color {
        switch status {
        case .authorized, .limited:
            .green
        case .notDetermined:
            .secondary
        case .denied, .restricted, .unknown:
            .red
        }
    }
}
#endif
