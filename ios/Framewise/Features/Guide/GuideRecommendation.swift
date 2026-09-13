//
//  GuideRecommendation.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/13.
//

import SwiftUI

struct GuideRecommendation: View {
    let title: LocalizedStringKey
    let previews: [GuidePreview]
    let aspectRatio: GuidePreviewAspectRatio

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(
                    .custom(
                        "DingTalk-JinBuTi",
                        size: 18,
                        relativeTo: .headline
                    )
                )
                .padding(.horizontal, 20)

            GuideCarousel(
                previews: previews,
                aspectRatio: aspectRatio
            )
        }
        .padding(.bottom, 28)
    }
}
