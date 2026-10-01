//
//  SearchTemplateCard.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import SwiftUI

struct SearchTemplateCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let mask: MaskContent
    var aspectRatioOverride: CGFloat? = nil

    private var aspectRatio: CGFloat {
        if let aspectRatioOverride { return aspectRatioOverride }
        let ratio = mask.defaultVariant.aspectRatio
        return CGFloat(ratio.width / ratio.height)
    }

    private var aspectRatioLabel: String {
        let ratio = mask.defaultVariant.aspectRatio
        return "\(Int(ratio.width)):\(Int(ratio.height))"
    }

    private var placeholderColor: Color {
        let colorIndex = mask.id.utf8.reduce(0) { ($0 + Int($1)) % 12 }
        return Color(
            hue: Double(colorIndex) / 12,
            saturation: colorScheme == .dark ? 0.22 : 0.16,
            brightness: colorScheme == .dark ? 0.38 : 0.93
        )
    }

    var body: some View {
        placeholderColor
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                ViewThatFits(in: .vertical) {
                    VStack(alignment: .leading, spacing: 4) {
                        title
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("推荐 \(aspectRatioLabel)")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        title
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(aspectRatioLabel)
                            .font(.caption.monospacedDigit())
                            .fixedSize()
                    }
                }
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    .white.opacity(colorScheme == .dark ? 0.10 : 0.40),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(mask.localization.title)，推荐比例 \(aspectRatioLabel)")
            .accessibilityHint("使用这个模版打开相机")
    }

    private var title: some View {
        Text(mask.localization.title)
            .font(.subheadline.weight(.semibold))
    }
}
