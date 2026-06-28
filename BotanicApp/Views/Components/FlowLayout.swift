import SwiftUI

/// A simple wrapping flow layout: lays children left-to-right, wrapping to a new line when the row
/// would overflow. Used for tag/chip groups.
struct FlowLayout: Layout {
    var spacing: CGFloat = 9
    var lineSpacing: CGFloat = 9

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, maxWidth: maxWidth)
        let height = rows.last?.maxY ?? 0
        return CGSize(width: maxWidth == .infinity ? rows.map(\.width).max() ?? 0 : maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layout(subviews: subviews, maxWidth: bounds.width)
        for row in rows {
            for item in row.items {
                let pt = CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y)
                subviews[item.index].place(at: pt, anchor: .topLeading, proposal: ProposedViewSize(item.size))
            }
        }
    }

    private struct Row {
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
        var maxY: CGFloat { y + height }
    }

    private func layout(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !current.items.isEmpty {
                current.width = x - spacing
                rows.append(current)
                current = Row(y: current.maxY + lineSpacing)
                x = 0
            }
            current.items.append((index, x, size))
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }
        if !current.items.isEmpty {
            current.width = x - spacing
            rows.append(current)
        }
        return rows
    }
}
