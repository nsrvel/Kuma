import CoreGraphics

/// Deck grid column math shared by the collection view layout.
enum ServiceDeckColumnMetrics {
    static func columnCount(forWidth width: CGFloat, minColumnWidth: CGFloat, spacing: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return 1 }
        return max(1, Int((width + spacing) / (minColumnWidth + spacing)))
    }
}
