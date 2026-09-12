//
//  GuideQuickView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct GuideQuickView: View {
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            GuideQuickCard(title: "拍人像", description: "单人 · 合照 · 街拍") {
                GuidePortraitArtwork()
            }

            GuideQuickCard(title: "拍风景", description: "山川 · 湖海 · 日落") {
                GuideLandscapeArtwork()
            }

            GuideQuickCard(title: "拍建筑", description: "街巷 · 楼宇 · 地标") {
                GuideArchitectureArtwork()
            }

            GuideQuickCard(title: "拍静物", description: "美食 · 花草 · 小物") {
                GuideStillLifeArtwork()
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible()),
        ]
    }
}
