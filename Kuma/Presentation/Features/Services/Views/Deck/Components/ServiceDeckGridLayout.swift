import SwiftUI

/// Responsive card grid: column count derives from the proposed width inside one layout pass.
/// ponytail: non-lazy — every card is instantiated. Fine for tens of services; switch to LazyVGrid
/// if a workspace grows into the hundreds and Instruments shows slow initial load.
struct ServiceDeckGridLayout: Layout {
    struct Cache {
        var width: CGFloat = -1
        var columns: Int = 1
        var columnWidth: CGFloat = 0
        var rowHeights: [CGFloat] = []
    }

    var minColumnWidth: CGFloat = 280
    var spacing: CGFloat = 16
    /// When set, skips per-card `sizeThatFits` during layout (resize stays cheap if card height is stable).
    var estimatedRowHeight: CGFloat?

    static func columnCount(forWidth width: CGFloat, minColumnWidth: CGFloat, spacing: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return 1 }
        return max(1, Int((width + spacing) / (minColumnWidth + spacing)))
    }

    private func metrics(width: CGFloat) -> (columns: Int, columnWidth: CGFloat) {
        let columns = Self.columnCount(forWidth: width, minColumnWidth: minColumnWidth, spacing: spacing)
        let columnWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        return (columns, columnWidth)
    }

    private func computeRowHeights(subviews: Subviews, columns: Int, columnWidth: CGFloat) -> [CGFloat] {
        if let estimatedRowHeight, estimatedRowHeight > 0 {
            let rowCount = (subviews.count + columns - 1) / columns
            return Array(repeating: estimatedRowHeight, count: rowCount)
        }
        let proposal = ProposedViewSize(width: columnWidth, height: nil)
        return stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(proposal).height }
                .max() ?? 0
        }
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    private func refreshCache(width: CGFloat, subviews: Subviews, cache: inout Cache) {
        let (columns, columnWidth) = metrics(width: width)
        if cache.width == width, cache.columns == columns, !cache.rowHeights.isEmpty {
            return
        }
        cache.width = width
        cache.columns = columns
        cache.columnWidth = columnWidth
        cache.rowHeights = computeRowHeights(subviews: subviews, columns: columns, columnWidth: columnWidth)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? (minColumnWidth * 3 + spacing * 2)
        guard !subviews.isEmpty else { return CGSize(width: width, height: 0) }
        refreshCache(width: width, subviews: subviews, cache: &cache)
        let height = cache.rowHeights.reduce(0, +) + spacing * CGFloat(max(cache.rowHeights.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard !subviews.isEmpty else { return }
        refreshCache(width: bounds.width, subviews: subviews, cache: &cache)
        let columns = cache.columns
        let columnWidth = cache.columnWidth
        var y = bounds.minY
        for (row, rowHeight) in cache.rowHeights.enumerated() {
            for column in 0..<columns {
                let index = row * columns + column
                guard index < subviews.count else { break }
                let x = bounds.minX + CGFloat(column) * (columnWidth + spacing)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: columnWidth, height: rowHeight)
                )
            }
            y += rowHeight + spacing
        }
    }
}
