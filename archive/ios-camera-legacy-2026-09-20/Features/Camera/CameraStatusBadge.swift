//
//  CameraStatusBadge.swift
//  Framewise legacy camera snapshot
//
//  Created by Codex on 2026/9/19.
//

import SwiftUI

struct CameraStatusBadge: View {
    enum Palette {
        case yellow
        case light
    }

    let title: LocalizedStringKey
    var palette = Palette.yellow

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }

    private var backgroundColor: Color {
        switch palette {
        case .yellow:
            .yellow
        case .light:
            Color(white: 0.96)
        }
    }
}

#Preview {
    ZStack {
        Color.black

        VStack(spacing: 16) {
            CameraStatusBadge(title: "请旋转手机")
            CameraStatusBadge(title: "关闭实况", palette: .light)
        }
    }
}
