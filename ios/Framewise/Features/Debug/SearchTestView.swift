#if DEBUG
    import SwiftUI

    struct SearchTestView: View {
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        @State private var searchText = ""

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
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("共 \(filteredMasks.count) 个模版")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("轻点开始拍摄，长按查看完整画幅")
                            .font(.caption)
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
                                    templateButton(mask, availableSize: geometry.size)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("SearchTest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索模版名称或关键词"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }

        private func templateButton(
            _ mask: MaskContent,
            availableSize: CGSize
        ) -> some View {
            let ratio = mask.defaultVariant.aspectRatio
            let originalAspectRatio = CGFloat(ratio.width / ratio.height)
            // Reserve vertical room for the system's context menu below the full-frame preview.
            let previewWidth = min(
                max(0, availableSize.width - 32),
                availableSize.height * 0.65 * originalAspectRatio
            )

            return Button {
                openCamera(for: mask)
            } label: {
                SearchTemplateCard(
                    mask: mask,
                    aspectRatioOverride: originalAspectRatio > 1 ? 3.0 / 4.0 : nil
                )
            }
            .buttonStyle(.plain)
            .contentShape(
                .contextMenuPreview,
                RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .accessibilityHint("轻点使用模版拍摄，长按预览完整画幅")
            .contextMenu {
                Button("使用模版拍摄", systemImage: "camera") {
                    openCamera(for: mask)
                }
            } preview: {
                SearchTemplateCard(mask: mask)
                    .frame(width: previewWidth)
                    .accessibilityHint("完整画幅预览")
            }
        }

        private func openCamera(for mask: MaskContent) {
            onCameraRequest(
                CameraMaskRequest(maskId: mask.id, relatedMaskIds: [])
            )
        }
    }
#endif
