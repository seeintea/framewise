//
//  GuideView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct GuideView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let recommendations: [GuideRecommendation] = [
        GuideRecommendation(
            title: "在风景里留个影",
            backgroundColors: [
                Color(hex: 0xE9F0E5), Color(hex: 0xF6EBDD),
                Color(hex: 0xE4EEF4),
            ]
        ),
        GuideRecommendation(
            title: "走到街角，拍一张",
            backgroundColors: [
                Color(hex: 0xE5EFF5), Color(hex: 0xF1E8DC),
                Color(hex: 0xE7EEE6),
            ]
        ),
        GuideRecommendation(
            title: "记录喜欢的事物",
            backgroundColors: [
                Color(hex: 0xF6ECD8), Color(hex: 0xF2E6DF),
                Color(hex: 0xE6EFE9),
            ]
        ),
        GuideRecommendation(
            title: "遇到好看的天空",
            backgroundColors: [
                Color(hex: 0xE3EDF5), Color(hex: 0xEBE8F2),
                Color(hex: 0xF3E8DC),
            ]
        ),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                GuideHeader()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                GuideQuickView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 5) {
                    Text("找点构图灵感")
                        .font(.title2.bold())

                    Text("左右滑动，看看不同的画面")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                ForEach(recommendations.indices, id: \.self) { index in
                    GuideRecommendationRow(
                        recommendation: recommendations[index]
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
                colors: backgroundGradient
            )
            .ignoresSafeArea()
        }
    }

    private var backgroundGradient: [Color] {
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

private struct GuideRecommendationRow: View {
    let recommendation: GuideRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recommendation.title)
                .font(.headline)
                .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(recommendation.backgroundColors.indices, id: \.self)
                    { index in
                        GuidePreviewCard(
                            backgroundColor: recommendation.backgroundColors[
                                index
                            ],
                            variant: index
                        )
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(.bottom, 28)
    }
}

private struct GuidePreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let backgroundColor: Color
    let variant: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backgroundColor.opacity(colorScheme == .dark ? 0.58 : 1)

            Circle()
                .fill(.white.opacity(0.51))
                .frame(width: 30, height: 30)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topTrailing
                )
                .padding(.top, 25)
                .padding(.trailing, 23)

            Ellipse()
                .fill(Color(hex: 0x456D60).opacity(0.32))
                .frame(width: 160, height: 135)
                .rotationEffect(shapeRotation)
                .offset(shapeOffset)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
                .padding(15)

            HStack(spacing: 5) {
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .medium))

                Text("示例图")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color(hex: 0x536251))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                .white.opacity(0.91),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white, lineWidth: 0.5)
            }
            .padding(.leading, 14)
            .padding(.bottom, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(9)
        .frame(width: 164, height: 218)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
        }
        .shadow(color: Color(hex: 0x26352F).opacity(0.07), radius: 14, y: 5)
        .accessibilityElement(children: .combine)
    }

    private var shapeOffset: CGSize {
        switch variant {
        case 1:
            CGSize(width: 42, height: 34)
        case 2:
            CGSize(width: 86, height: 16)
        default:
            CGSize(width: -16, height: 22)
        }
    }

    private var shapeRotation: Angle {
        switch variant {
        case 1:
            .degrees(-8)
        case 2:
            .degrees(18)
        default:
            .degrees(12)
        }
    }
}

private struct GuideRecommendation {
    let title: LocalizedStringKey
    let backgroundColors: [Color]
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
