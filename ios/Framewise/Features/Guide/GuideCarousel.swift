//
//  GuideCarousel.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct GuideCarousel: View {
    let previews: [GuidePreview]
    let aspectRatio: GuidePreviewAspectRatio
    let onSelect: (GuidePreview) -> Void

    init(
        previews: [GuidePreview],
        aspectRatio: GuidePreviewAspectRatio,
        onSelect: @escaping (GuidePreview) -> Void = { _ in }
    ) {
        self.previews = previews
        self.aspectRatio = aspectRatio
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(previews) { preview in
                    GuidePreviewCard(
                        preview: preview,
                        aspectRatio: aspectRatio,
                        onSelect: onSelect
                    )
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }
}

struct GuidePreview: Identifiable {
    let id: String
    let imageURL: URL?
}

enum GuidePreviewAspectRatio {
    case landscape4x3
    case portrait3x4

    fileprivate var value: CGFloat {
        switch self {
        case .landscape4x3:
            4.0 / 3.0
        case .portrait3x4:
            3.0 / 4.0
        }
    }
}

private struct GuidePreviewCard: View {
    let preview: GuidePreview
    let aspectRatio: GuidePreviewAspectRatio
    let onSelect: (GuidePreview) -> Void

    private let cardHeight: CGFloat = 218

    var body: some View {
        Button {
            onSelect(preview)
        } label: {
            AsyncImage(
                url: preview.imageURL,
                transaction: Transaction(animation: .easeInOut(duration: 0.2))
            ) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    imagePlaceholder(showProgress: false)
                case .empty:
                    imagePlaceholder(showProgress: true)
                @unknown default:
                    imagePlaceholder(showProgress: false)
                }
            }
            .frame(
                width: cardHeight * aspectRatio.value,
                height: cardHeight
            )
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    Image("GuideInspiration")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)

                    Text("照着拍")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.42), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.28), lineWidth: 0.5)
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        Color(uiColor: .separator).opacity(0.24),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color(hex: 0x26352F).opacity(0.09),
                radius: 14,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("照着拍")
    }

    private func imagePlaceholder(showProgress: Bool) -> some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)

            if showProgress {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
