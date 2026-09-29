//
//  SearchTemplateLayout.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/29.
//

import SwiftUI

struct SearchTemplateLayout: Layout {
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
