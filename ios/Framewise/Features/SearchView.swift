//
//  SearchView.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    let masks: [MaskContent]
    let onCameraRequest: (CameraMaskRequest) -> Void

    private var filteredMasks: [MaskContent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return masks }

        return masks.filter { mask in
            mask.localization.title.localizedStandardContains(query)
                || mask.localization.description.localizedStandardContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("共 \(filteredMasks.count) 个模版")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if filteredMasks.isEmpty {
                        ContentUnavailableView(
                            "没有找到模版",
                            systemImage: "magnifyingglass",
                            description: Text("换个名称或关键词试试。")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        SearchTemplateLayout(
                            columnCount: dynamicTypeSize.isAccessibilitySize ? 1 : 2,
                            spacing: 12
                        ) {
                            ForEach(filteredMasks) { mask in
                                Button {
                                    onCameraRequest(
                                        CameraMaskRequest(
                                            maskId: mask.id,
                                            relatedMaskIds: []
                                        )
                                    )
                                } label: {
                                    SearchTemplateCard(mask: mask)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("全部模版")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("搜索模版名称或关键词", text: $searchText)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
                .onSubmit { isSearchFocused = false }
                .accessibilityLabel("搜索模版")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 52)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

private struct SearchTemplateCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let mask: MaskContent

    private var aspectRatio: CGFloat {
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

private struct SearchTemplateLayout: Layout {
    let columnCount: Int
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width: CGFloat
        if let proposedWidth = proposal.width, proposedWidth.isFinite {
            width = proposedWidth
        } else {
            let idealColumnWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
            width = idealColumnWidth * CGFloat(columnCount) + spacing * CGFloat(columnCount - 1)
        }

        let frames = cardFrames(width: width, subviews: subviews)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let frames = cardFrames(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: nil)
            )
        }
    }

    private func cardFrames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let columnWidth = max(
            0, (width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount))
        let cardProposal = ProposedViewSize(width: columnWidth, height: nil)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        return subviews.map { subview in
            var column = 0
            for candidate in 1..<columnCount where columnHeights[candidate] < columnHeights[column]
            {
                column = candidate
            }

            // The caption is an overlay, so the cover alone determines the card's aspect ratio.
            let height = subview.sizeThatFits(cardProposal).height
            let frame = CGRect(
                x: CGFloat(column) * (columnWidth + spacing),
                y: columnHeights[column],
                width: columnWidth,
                height: height
            )
            columnHeights[column] = frame.maxY + spacing
            return frame
        }
    }
}
