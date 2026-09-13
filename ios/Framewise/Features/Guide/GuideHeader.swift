//
//  GuideHeader.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/12.
//

import SwiftUI

struct GuideHeader: View {
    let onCameraTap: () -> Void

    init(onCameraTap: @escaping () -> Void = {}) {
        self.onCameraTap = onCameraTap
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text("✦")
                        .font(.caption2)

                    Text("随手定格眼前的美好")
                        .font(
                            .custom(
                                "DingTalk-JinBuTi",
                                size: 12,
                                relativeTo: .caption
                            )
                        )

                }
                .foregroundStyle(Color(hex: 0x718099))

                Text("今天想拍什么？")
                    .font(
                        .custom(
                            "DingTalk-JinBuTi",
                            size: 34,
                            relativeTo: .largeTitle
                        )
                    )
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            cameraButton
        }
    }

    @ViewBuilder
    private var cameraButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: onCameraTap) {
                cameraButtonLabel
                    .padding(.horizontal, 2)
                    .frame(height: 30)
            }
            .buttonStyle(.glass)
        } else {
            Button(action: onCameraTap) {
                cameraButtonLabel
                    .padding(.horizontal, 12)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .background(
                Color(uiColor: .systemBackground).opacity(0.9),
                in: Capsule()
            )
            .shadow(color: Color(hex: 0x536078).opacity(0.05), radius: 10, y: 4)
        }
    }

    private var cameraButtonLabel: some View {
        HStack(spacing: 6) {
            Image("GuideCamera")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color(hex: 0x718099))
                .accessibilityHidden(true)

            Text("拍一张")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
