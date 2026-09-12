//
//  GuideQuickCard.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct GuideQuickCard<Artwork: View>: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let artwork: Artwork

    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.title = title
        self.description = description
        self.artwork = artwork()
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            artwork

            LinearGradient(
                colors: [.clear, Color(hex: 0x253630).opacity(0.58)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .opacity(0.84)
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 152)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: Color(hex: 0x27342F).opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

struct GuidePortraitArtwork: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(hex: 0x513B4B), Color(hex: 0x8A6258)]
                        : [Color(hex: 0xF2D7D0), Color(hex: 0xE6B89F)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(colorScheme == .dark ? 0.12 : 0.34))
                    .frame(width: 96, height: 96)
                    .position(x: proxy.size.width * 0.69, y: 52)

                Ellipse()
                    .fill(
                        Color(hex: colorScheme == .dark ? 0x59433E : 0x9A6558)
                    )
                    .frame(width: 82, height: 96)
                    .position(x: proxy.size.width * 0.7, y: 129)

                Circle()
                    .fill(
                        Color(hex: colorScheme == .dark ? 0xC89278 : 0xDDA486)
                    )
                    .frame(width: 40, height: 40)
                    .position(x: proxy.size.width * 0.7, y: 57)

                Circle()
                    .trim(from: 0.1, to: 0.7)
                    .stroke(
                        Color(hex: colorScheme == .dark ? 0x30272C : 0x5E4543),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .rotationEffect(.degrees(160))
                    .frame(width: 43, height: 43)
                    .position(x: proxy.size.width * 0.7, y: 55)

                Ellipse()
                    .fill(Color(hex: 0xA76755).opacity(0.55))
                    .frame(width: 112, height: 48)
                    .rotationEffect(.degrees(18))
                    .position(x: 18, y: 126)
            }
        }
    }
}

struct GuideLandscapeArtwork: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: 0x34485A), Color(hex: 0x725C57)]
                    : [Color(hex: 0xC9E0EC), Color(hex: 0xF2D9C5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(colorScheme == .dark ? 0.42 : 0.72))
                .frame(width: 34, height: 34)
                .blur(radius: 0.4)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topTrailing
                )
                .padding(.top, 18)
                .padding(.trailing, 20)

            GuideDistantHill()
                .fill(Color(hex: colorScheme == .dark ? 0x5F7774 : 0x88AAA3))
                .offset(y: 8)

            GuideForegroundHill()
                .fill(Color(hex: colorScheme == .dark ? 0x334D47 : 0x52796F))
                .offset(y: 24)
        }
    }
}

struct GuideArchitectureArtwork: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(hex: 0x263C4B), Color(hex: 0x58646B)]
                        : [Color(hex: 0xCEE2ED), Color(hex: 0xE8DCD0)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(.white.opacity(colorScheme == .dark ? 0.16 : 0.48))
                    .frame(width: 56, height: 56)
                    .position(x: 36, y: 34)

                building(
                    color: Color(
                        hex: colorScheme == .dark ? 0x687B82 : 0x91AEB8
                    ),
                    windowColor: Color(hex: 0xF6D6A8),
                    rows: 4
                )
                .frame(width: 54, height: 120)
                .position(x: proxy.size.width * 0.59, y: 94)

                building(
                    color: Color(
                        hex: colorScheme == .dark ? 0x425B67 : 0x5E8798
                    ),
                    windowColor: Color(hex: 0xEED19D),
                    rows: 3
                )
                .frame(width: 48, height: 92)
                .position(x: proxy.size.width * 0.86, y: 111)

                GuideStreetShape()
                    .fill(
                        Color(hex: colorScheme == .dark ? 0x26363B : 0x718886)
                    )
                    .offset(y: 36)
            }
        }
    }

    private func building(
        color: Color,
        windowColor: Color,
        rows: Int
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color)

            VStack(spacing: 9) {
                ForEach(0..<rows, id: \.self) { _ in
                    HStack(spacing: 9) {
                        windowColor.frame(width: 7, height: 9)
                        windowColor.opacity(0.72).frame(width: 7, height: 9)
                    }
                }
            }
        }
    }
}

struct GuideStillLifeArtwork: View {
    @Environment(\.colorScheme) private var colorScheme

    private let petalOffsets: [CGSize] = [
        CGSize(width: 0, height: -17),
        CGSize(width: 17, height: -5),
        CGSize(width: 10, height: 14),
        CGSize(width: -10, height: 14),
        CGSize(width: -17, height: -5),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(hex: 0x584535), Color(hex: 0x826A45)]
                        : [Color(hex: 0xF4DFC0), Color(hex: 0xE9C985)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(colorScheme == .dark ? 0.12 : 0.3))
                    .frame(width: 92, height: 92)
                    .position(x: proxy.size.width * 0.76, y: 40)

                Capsule()
                    .fill(
                        Color(hex: colorScheme == .dark ? 0x6C856D : 0x77936E)
                    )
                    .frame(width: 7, height: 64)
                    .rotationEffect(.degrees(9))
                    .position(x: proxy.size.width * 0.67, y: 57)

                ForEach(petalOffsets.indices, id: \.self) { index in
                    Circle()
                        .fill(
                            Color(
                                hex: index.isMultiple(of: 2)
                                    ? 0xD77A5F : 0xF1A66A
                            )
                        )
                        .frame(width: 25, height: 25)
                        .position(
                            x: proxy.size.width * 0.67
                                + petalOffsets[index].width,
                            y: 29 + petalOffsets[index].height
                        )
                }

                Circle()
                    .fill(Color(hex: 0x805842))
                    .frame(width: 16, height: 16)
                    .position(x: proxy.size.width * 0.67, y: 29)

                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 10,
                    style: .continuous
                )
                .fill(Color(hex: colorScheme == .dark ? 0xA77B67 : 0xC98C72))
                .frame(width: 58, height: 64)
                .position(x: proxy.size.width * 0.67, y: 103)

                Ellipse()
                    .fill(
                        Color(hex: colorScheme == .dark ? 0x3F3430 : 0xB17C55)
                            .opacity(0.55)
                    )
                    .frame(width: 132, height: 40)
                    .position(x: 22, y: 137)
            }
        }
    }
}

private struct GuideDistantHill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.6))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.48),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.36),
            control2: CGPoint(x: rect.width * 0.34, y: rect.height * 0.68)
        )
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.58),
            control1: CGPoint(x: rect.width * 0.75, y: rect.height * 0.36),
            control2: CGPoint(x: rect.width * 0.88, y: rect.height * 0.54)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct GuideForegroundHill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.7))
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.54),
            control1: CGPoint(x: rect.width * 0.3, y: rect.height * 0.82),
            control2: CGPoint(x: rect.width * 0.66, y: rect.height * 0.35)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct GuideStreetShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.76))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.54))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
