//
//  GuideView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct GuideView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let quickEntries: [GuideQuickEntry] = [
        GuideQuickEntry(
            title: "拍人物",
            description: "单人 · 合照",
            symbolName: "person",
            backgroundColor: Color(hex: 0xFEF2EB),
            borderColor: Color(hex: 0xF5DED0),
            iconColor: Color(hex: 0xD87956),
            focus: .top
        ),
        GuideQuickEntry(
            title: "拍风景",
            description: "山川 · 湖海 · 日落",
            symbolName: "mountain.2",
            backgroundColor: Color(hex: 0xEDF4EC),
            borderColor: Color(hex: 0xD8E5D5),
            iconColor: Color(hex: 0x5C7E59),
            focus: .right
        ),
        GuideQuickEntry(
            title: "拍建筑",
            description: "街道 · 楼宇 · 地标",
            symbolName: "building.2",
            backgroundColor: Color(hex: 0xEAF2F8),
            borderColor: Color(hex: 0xD6E3EB),
            iconColor: Color(hex: 0x4C7895),
            focus: .center
        ),
        GuideQuickEntry(
            title: "拍静物",
            description: "美食 · 花草 · 小物",
            symbolName: "cup.and.saucer",
            backgroundColor: Color(hex: 0xFFF5E2),
            borderColor: Color(hex: 0xFAE8C9),
            iconColor: Color(hex: 0xC28735),
            focus: .bottom
        ),
    ]

    private let recommendations: [GuideRecommendation] = [
        GuideRecommendation(
            title: "在风景里留个影",
            backgroundColors: [Color(hex: 0xE9F0E5), Color(hex: 0xF6EBDD), Color(hex: 0xE4EEF4)]
        ),
        GuideRecommendation(
            title: "走到街角，拍一张",
            backgroundColors: [Color(hex: 0xE5EFF5), Color(hex: 0xF1E8DC), Color(hex: 0xE7EEE6)]
        ),
        GuideRecommendation(
            title: "记录喜欢的事物",
            backgroundColors: [Color(hex: 0xF6ECD8), Color(hex: 0xF2E6DF), Color(hex: 0xE6EFE9)]
        ),
        GuideRecommendation(
            title: "遇到好看的天空",
            backgroundColors: [Color(hex: 0xE3EDF5), Color(hex: 0xEBE8F2), Color(hex: 0xF3E8DC)]
        ),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                GuideHeader()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(quickEntries.indices, id: \.self) { index in
                        GuideQuickEntryView(entry: quickEntries[index])
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 5) {
                    Text("找点构图灵感")
                        .font(.title2.bold())

                    Text("左右滑动，看看不同的画面")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 20)

                ForEach(recommendations.indices, id: \.self) { index in
                    GuideRecommendationRow(recommendation: recommendations[index])
                }
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .background {
            LinearGradient(
                colors: backgroundGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible()),
        ]
    }

    private var backgroundGradient: [Color] {
        if colorScheme == .dark {
            [Color(hex: 0x17202B), Color(hex: 0x111820), Color(hex: 0x0D1014)]
        } else {
            [Color(hex: 0xE3EAF4), Color(hex: 0xF0F4F8), Color(hex: 0xFAFAFB)]
        }
    }
}

private struct GuideHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text("✦")
                        .font(.caption2)

                    Text("随手定格眼前的美好")
                        .font(.caption)
                }
                .foregroundStyle(Color(hex: 0x718099))

                Text("今天想拍什么？")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: "camera")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Color(hex: 0x718099))

                Text("拍一张")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(uiColor: .systemBackground).opacity(0.9), in: Capsule())
            .shadow(color: Color(hex: 0x536078).opacity(0.05), radius: 10, y: 4)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct GuideQuickEntryView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: GuideQuickEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GuideCompositionSketch(entry: entry)
                .frame(width: 88, height: 76)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 10)
                .padding(.trailing, 9)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(entry.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 152, alignment: .bottomLeading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(entry.borderColor.opacity(colorScheme == .dark ? 0.45 : 1), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: 0x27342F).opacity(0.055), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var cardBackground: Color {
        entry.backgroundColor.opacity(colorScheme == .dark ? 0.22 : 1)
    }
}

private struct GuideCompositionSketch: View {
    let entry: GuideQuickEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(entry.iconColor.opacity(0.3))
                .frame(width: 0.5)
                .offset(x: 34)

            Rectangle()
                .fill(entry.iconColor.opacity(0.3))
                .frame(height: 0.5)
                .offset(y: 30)

            Image(systemName: entry.symbolName)
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(entry.iconColor.opacity(0.46))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: -3, y: 4)

            Circle()
                .fill(entry.iconColor)
                .stroke(entry.backgroundColor, lineWidth: 2)
                .frame(width: 8, height: 8)
                .position(entry.focus.position)
        }
        .accessibilityHidden(true)
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
                    ForEach(recommendation.backgroundColors.indices, id: \.self) { index in
                        GuidePreviewCard(
                            backgroundColor: recommendation.backgroundColors[index],
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
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
                .white.opacity(0.91), in: RoundedRectangle(cornerRadius: 9, style: .continuous)
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

private struct GuideQuickEntry {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let symbolName: String
    let backgroundColor: Color
    let borderColor: Color
    let iconColor: Color
    let focus: GuideFocusPoint
}

private struct GuideRecommendation {
    let title: LocalizedStringKey
    let backgroundColors: [Color]
}

private enum GuideFocusPoint {
    case top
    case center
    case bottom
    case right

    var position: CGPoint {
        switch self {
        case .top:
            CGPoint(x: 34, y: 30)
        case .center:
            CGPoint(x: 54, y: 30)
        case .bottom:
            CGPoint(x: 34, y: 55)
        case .right:
            CGPoint(x: 73, y: 30)
        }
    }
}

extension Color {
    fileprivate init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
