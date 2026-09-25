import SwiftUI
import AppKit

/// High-performance AppKit-backed log console for terminal logs.
public struct KumaLogConsoleView: NSViewRepresentable {
    public let entries: [LiveLogEntry]
    public let isAutoScroll: Bool
    public var emptyPlaceholder: String

    public init(
        entries: [LiveLogEntry],
        isAutoScroll: Bool = true,
        emptyPlaceholder: String = "No logs available"
    ) {
        self.entries = entries
        self.isAutoScroll = isAutoScroll
        self.emptyPlaceholder = emptyPlaceholder
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 10, height: 10)

        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false

        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = NSColor.labelColor

        scrollView.documentView = textView
        context.coordinator.resetRenderState()

        updateTextView(textView, context: context, forceFullRebuild: true)
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        let canAppend = context.coordinator.canAppendTail(entries: entries)
        updateTextView(textView, context: context, forceFullRebuild: !canAppend)

        if context.coordinator.contentDirty && isAutoScroll {
            context.coordinator.scrollToBottom(textView: textView, in: nsView)
        }
        context.coordinator.contentDirty = false
    }

    private func updateTextView(_ textView: NSTextView, context: Context, forceFullRebuild: Bool) {
        guard let textStorage = textView.textStorage else { return }

        if entries.isEmpty {
            context.coordinator.resetRenderState()
            let attrString = NSAttributedString(
                string: emptyPlaceholder,
                attributes: LogRowFormatter.placeholderAttributes
            )
            textStorage.setAttributedString(attrString)
            context.coordinator.contentDirty = true
            return
        }

        if forceFullRebuild {
            let formatted = LogRowFormatter.fullDocument(for: entries)
            textStorage.setAttributedString(formatted)
            context.coordinator.lastRenderedCount = entries.count
            context.coordinator.firstEntryID = entries.first?.id
            context.coordinator.lastEntriesID = entries.last?.id
            context.coordinator.contentDirty = true
            return
        }

        let startIndex = context.coordinator.lastRenderedCount
        guard startIndex < entries.count else { return }

        let appendBlock = LogRowFormatter.appendBlock(entries: entries, from: startIndex)
        textStorage.append(appendBlock)
        context.coordinator.lastRenderedCount = entries.count
        context.coordinator.lastEntriesID = entries.last?.id
        context.coordinator.contentDirty = true
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    public final class Coordinator: NSObject {
        var lastRenderedCount: Int = 0
        var firstEntryID: UUID?
        var lastEntriesID: UUID?
        var contentDirty: Bool = false
        private var isScrolling: Bool = false

        func resetRenderState() {
            lastRenderedCount = 0
            firstEntryID = nil
            lastEntriesID = nil
            contentDirty = false
        }

        func canAppendTail(entries: [LiveLogEntry]) -> Bool {
            guard !entries.isEmpty, lastRenderedCount > 0 else { return false }
            guard entries.count >= lastRenderedCount else { return false }
            guard entries.first?.id == firstEntryID else { return false }
            if entries.count == lastRenderedCount {
                return entries.last?.id == lastEntriesID
            }
            return entries.count > lastRenderedCount
        }

        func scrollToBottom(textView: NSTextView, in scrollView: NSScrollView) {
            guard !isScrolling else { return }
            isScrolling = true
            defer { isScrolling = false }
            let length = textView.string.utf16.count
            if length > 0 {
                textView.scrollRangeToVisible(NSRange(location: length, length: 0))
            }
        }
    }
}

// MARK: - Row formatting

private enum LogRowFormatter {
    static let placeholderAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor.secondaryLabelColor
    ]

    static func fullDocument(for entries: [LiveLogEntry]) -> NSMutableAttributedString {
        let formatted = NSMutableAttributedString()
        for (index, entry) in entries.enumerated() {
            formatted.append(row(entry, appendNewline: index < entries.count - 1))
        }
        return formatted
    }

    static func appendBlock(entries: [LiveLogEntry], from startIndex: Int) -> NSMutableAttributedString {
        let block = NSMutableAttributedString()
        if startIndex > 0 {
            block.append(NSAttributedString(string: "\n", attributes: messageAttributes))
        }
        for index in startIndex..<entries.count {
            block.append(row(entries[index], appendNewline: index < entries.count - 1))
        }
        return block
    }

    private static let timestampFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
    private static let nameFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    private static let levelFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
    private static let msgFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private static let timeColor = NSColor.secondaryLabelColor.withAlphaComponent(0.65)
    private static let nameColor = NSColor.controlAccentColor
    private static let msgAttributes: [NSAttributedString.Key: Any] = [
        .font: msgFont,
        .foregroundColor: NSColor.labelColor.withAlphaComponent(0.92)
    ]
    private static let messageAttributes: [NSAttributedString.Key: Any] = [
        .font: msgFont,
        .foregroundColor: NSColor.labelColor.withAlphaComponent(0.92)
    ]

    private static func row(_ entry: LiveLogEntry, appendNewline: Bool) -> NSAttributedString {
        let row = NSMutableAttributedString()
        row.append(NSAttributedString(
            string: "\(entry.timestamp) ",
            attributes: [.font: timestampFont, .foregroundColor: timeColor]
        ))
        if !entry.serviceName.isEmpty {
            row.append(NSAttributedString(
                string: "[\(entry.serviceName)] ",
                attributes: [.font: nameFont, .foregroundColor: nameColor]
            ))
        }
        let lvlColor: NSColor
        switch entry.level.uppercased() {
        case "ERR", "ERROR": lvlColor = NSColor.systemRed
        case "WARN", "WARNING": lvlColor = NSColor.systemOrange
        case "OK", "SUCCESS": lvlColor = NSColor.systemGreen
        default: lvlColor = NSColor.systemTeal
        }
        row.append(NSAttributedString(
            string: "\(entry.level.uppercased()) ",
            attributes: [.font: levelFont, .foregroundColor: lvlColor]
        ))
        row.append(NSAttributedString(
            string: entry.message + (appendNewline ? "\n" : ""),
            attributes: msgAttributes
        ))
        return row
    }
}
