//
//  GuideView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

private let landscapeSamplePreviews = [
    GuidePreview(
        id: "vae-2024-06-01-1",
        imageURL: URL(
            string: "https://seeintea.github.io/static/images/photos/vae-2024-06-01.webp"
        )
    ),
    GuidePreview(
        id: "vae-2024-06-01-2",
        imageURL: URL(
            string: "https://seeintea.github.io/static/images/photos/vae-2024-06-01.webp"
        )
    ),
]

private let portraitSamplePreviews = [
    GuidePreview(
        id: "keong-saik-rd-2024-04-22-1",
        imageURL: URL(
            string: "https://seeintea.github.io/static/images/photos/keong-saik-rd-2024-04-22.webp"
        )
    ),
    GuidePreview(
        id: "keong-saik-rd-2024-04-22-2",
        imageURL: URL(
            string: "https://seeintea.github.io/static/images/photos/keong-saik-rd-2024-04-22.webp"
        )
    ),
    GuidePreview(
        id: "keong-saik-rd-2024-04-22-3",
        imageURL: URL(
            string: "https://seeintea.github.io/static/images/photos/keong-saik-rd-2024-04-22.webp"
        )
    ),
]

struct GuideView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onCameraRequest: (CameraTemplateRequest) -> Void

    init(onCameraRequest: @escaping (CameraTemplateRequest) -> Void = { _ in }) {
        self.onCameraRequest = onCameraRequest
    }

    private let recommendations: [RecommendationContent] = [
        RecommendationContent(
            title: "在风景里留个影",
            previews: landscapeSamplePreviews,
            aspectRatio: .landscape4x3
        ),
        RecommendationContent(
            title: "走到街角，拍一张",
            previews: portraitSamplePreviews,
            aspectRatio: .portrait3x4
        ),
        RecommendationContent(
            title: "记录喜欢的事物",
            previews: portraitSamplePreviews,
            aspectRatio: .portrait3x4
        ),
        RecommendationContent(
            title: "遇到好看的天空",
            previews: landscapeSamplePreviews,
            aspectRatio: .landscape4x3
        ),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                GuideHeader {
                    let templateId = CompositionTemplateIdentifier.classicRuleOfThirds

                    onCameraRequest(
                        CameraTemplateRequest(
                            templateIds: [templateId],
                            initialTemplateId: templateId
                        )
                    )
                }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                GuideQuickView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text("或者，找点构图灵感")
                        .font(
                            .custom(
                                "DingTalk-JinBuTi",
                                size: 24,
                                relativeTo: .title2
                            )
                        )

                    Text("从喜欢的画面出发，慢慢找到想拍的感觉")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                ForEach(recommendations.indices, id: \.self) { index in
                    GuideRecommendation(
                        title: recommendations[index].title,
                        previews: recommendations[index].previews,
                        aspectRatio: recommendations[index].aspectRatio
                    )
                }
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .background {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.54, 0.46], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: meshColors
            )
            .ignoresSafeArea()
        }
    }

    private var meshColors: [Color] {
        if colorScheme == .dark {
            [
                Color(hex: 0x1A2B3D), Color(hex: 0x2A2536),
                Color(hex: 0x352827),
                Color(hex: 0x172633), Color(hex: 0x1A2228),
                Color(hex: 0x1B2B28),
                Color(hex: 0x111820), Color(hex: 0x10151A),
                Color(hex: 0x0D1014),
            ]
        } else {
            [
                Color(hex: 0xD7E5F6), Color(hex: 0xEAE1F2),
                Color(hex: 0xF8E5D8),
                Color(hex: 0xE6EEF7), Color(hex: 0xF4F1E9),
                Color(hex: 0xE1EEE8),
                Color(hex: 0xF4F5F7), Color(hex: 0xEEF3F8),
                Color(hex: 0xFAFAFB),
            ]
        }
    }
}

private struct RecommendationContent {
    let title: LocalizedStringKey
    let previews: [GuidePreview]
    let aspectRatio: GuidePreviewAspectRatio
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}


#Preview {
    GuideView()
}
