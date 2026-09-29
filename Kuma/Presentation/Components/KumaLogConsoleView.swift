import SwiftUI
import AppKit

/// High-performance AppKit-backed log console for terminal logs.
public struct KumaLogConsoleView: NSViewRepresentable {
    public let entries: [LiveLogEntry]
    public let isAutoScroll: Bool
    public let wrapsLines: Bool
    public var emptyPlaceholder: String
    public var scrollToBottomRequest: Int
    public var onUserScrolledAwayFromBottom: (() -> Void)?

    public init(
        entries: [LiveLogEntry],
        isAutoScroll: Bool = true,
        wrapsLines: Bool = true,
        emptyPlaceholder: String = "No logs available",
        scrollToBottomRequest: Int = 0,
        onUserScrolledAwayFromBottom: (() -> Void)? = nil
    ) {
        self.entries = entries
        self.isAutoScroll = isAutoScroll
        self.wrapsLines = wrapsLines
        self.emptyPlaceholder = emptyPlaceholder
        self.scrollToBottomRequest = scrollToBottomRequest
        self.onUserScrolledAwayFromBottom = onUserScrolledAwayFromBottom
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = LogConsoleScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapsLines
        scrollView.autohidesScrollers = true
        scrollView.onBoundsChange = { [weak coordinator = context.coordinator] in
            coordinator?.handleBoundsChange()
        }

        let contentSize = scrollView.contentSize
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        applyLayout(to: textView, scrollView: scrollView)

        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false

        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = NSColor.labelColor

        scrollView.documentView = textView
        context.coordinator.attach(scrollView: scrollView, textView: textView)
        context.coordinator.lastWrapsLines = wrapsLines
        context.coordinator.resetRenderState()

        updateTextView(textView, context: context, forceFullRebuild: true)
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let scrollView = nsView as? LogConsoleScrollView,
              let textView = nsView.documentView as? NSTextView else { return }

        context.coordinator.onUserScrolledAwayFromBottom = onUserScrolledAwayFromBottom
        if context.coordinator.lastWrapsLines != wrapsLines {
            context.coordinator.lastWrapsLines = wrapsLines
            applyLayout(to: textView, scrollView: scrollView)
        }

        let canAppend = context.coordinator.canAppendTail(entries: entries)
        updateTextView(textView, context: context, forceFullRebuild: !canAppend)

        if context.coordinator.contentDirty && isAutoScroll {
            context.coordinator.scrollToBottom(programmatic: true)
        }
        context.coordinator.contentDirty = false

        if scrollToBottomRequest != context.coordinator.lastScrollToBottomRequest {
            context.coordinator.lastScrollToBottomRequest = scrollToBottomRequest
            context.coordinator.scrollToBottom(programmatic: true)
        }
    }

    private func applyLayout(to textView: NSTextView, scrollView: NSScrollView) {
        let contentSize = scrollView.contentSize
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wrapsLines
        textView.autoresizingMask = wrapsLines ? [.width] : [.width, .height]
        scrollView.hasHorizontalScroller = !wrapsLines
        if wrapsLines {
            textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
        } else {
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = false
        }
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 10, height: 10)
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
        var lastScrollToBottomRequest: Int = 0
        var onUserScrolledAwayFromBottom: (() -> Void)?
        var lastWrapsLines: Bool = true

        private weak var scrollView: LogConsoleScrollView?
        private weak var textView: NSTextView?
        private var isProgrammaticScroll = false
        private var notifiedScrolledAway = false

        fileprivate func attach(scrollView: LogConsoleScrollView, textView: NSTextView) {
            self.scrollView = scrollView
            self.textView = textView
        }

        func resetRenderState() {
            lastRenderedCount = 0
            firstEntryID = nil
            lastEntriesID = nil
            contentDirty = false
        }

        func canAppendTail(entries: [LiveLogEntry]) -> Bool {
            LogConsoleRenderState.canAppendTail(
                entries: entries,
                lastRenderedCount: lastRenderedCount,
                firstEntryID: firstEntryID,
                lastEntriesID: lastEntriesID
            )
        }

        func handleBoundsChange() {
            guard !isProgrammaticScroll else { return }
            guard let scrollView, let textView else { return }
            let pinned = scrollView.isPinnedToBottom(textView: textView)
            if pinned {
                notifiedScrolledAway = false
            } else if !notifiedScrolledAway {
                notifiedScrolledAway = true
                onUserScrolledAwayFromBottom?()
            }
        }

        func scrollToBottom(programmatic: Bool) {
            guard let scrollView, let textView else { return }
            isProgrammaticScroll = true
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.isProgrammaticScroll = false
                }
            }
            let length = textView.string.utf16.count
            if length > 0 {
                textView.scrollRangeToVisible(NSRange(location: length, length: 0))
            }
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}

// MARK: - Render state (testable)

enum LogConsoleRenderState: Sendable {
    nonisolated static func canAppendTail(
        entries: [LiveLogEntry],
        lastRenderedCount: Int,
        firstEntryID: UUID?,
        lastEntriesID: UUID?
    ) -> Bool {
        guard !entries.isEmpty, lastRenderedCount > 0 else { return false }
        guard entries.count >= lastRenderedCount else { return false }
        guard entries.first?.id == firstEntryID else { return false }
        if entries.count == lastRenderedCount {
            return entries.last?.id == lastEntriesID
        }
        return entries.count > lastRenderedCount
    }
}

private final class LogConsoleScrollView: NSScrollView {
    var onBoundsChange: (() -> Void)?

    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        onBoundsChange?()
    }

    func isPinnedToBottom(textView: NSTextView, threshold: CGFloat = 6) -> Bool {
        let clipView = contentView
        let visible = clipView.documentVisibleRect
        let docHeight = textView.bounds.height
        return visible.maxY >= docHeight - threshold
    }
}

// MARK: - Row formatting

@MainActor
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

    private static let msgFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private static let msgAttributes: [NSAttributedString.Key: Any] = [
        .font: msgFont,
        .foregroundColor: NSColor.labelColor.withAlphaComponent(0.92)
    ]
    private static let messageAttributes: [NSAttributedString.Key: Any] = [
        .font: msgFont,
        .foregroundColor: NSColor.labelColor.withAlphaComponent(0.92)
    ]

    private static func row(_ entry: LiveLogEntry, appendNewline: Bool) -> NSAttributedString {
        NSAttributedString(
            string: entry.message + (appendNewline ? "\n" : ""),
            attributes: msgAttributes
        )
    }
}
