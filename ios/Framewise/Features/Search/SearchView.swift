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
