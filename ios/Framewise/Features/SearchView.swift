//
//  SearchView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct SearchView: View {
    let masks: [MaskContent]
    let onCameraRequest: (CameraMaskRequest) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("共 \(masks.count) 个模版")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(masks) { mask in
                    Button {
                        onCameraRequest(
                            CameraMaskRequest(
                                maskId: mask.id,
                                relatedMaskIds: []
                            )
                        )
                    } label: {
                        SearchTemplateCard(
                            variant: mask.defaultVariant,
                            title: mask.localization.title,
                            description: mask.localization.description
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("全部模版")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SearchTemplateCard: View {
    let variant: MaskVariant
    let title: String
    let description: String

    private var aspectRatio: CGFloat {
        CGFloat(variant.aspectRatio.width / variant.aspectRatio.height)
    }

    private var aspectRatioLabel: String {
        "\(Int(variant.aspectRatio.width)):\(Int(variant.aspectRatio.height))"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.12, blue: 0.17),
                        Color(red: 0.20, green: 0.27, blue: 0.34),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                MaskCanvas(
                    variant: variant,
                    showsAnnotations: false,
                    lineWidth: 1
                )
                .padding(8)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(width: 96, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(aspectRatioLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Label("打开相机", systemImage: "camera")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityHint("使用这个模版打开相机")
    }
}
