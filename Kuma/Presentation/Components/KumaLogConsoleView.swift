import SwiftUI
import AppKit

public enum LogDisplayMode: Sendable, Equatable {
    /// Stream text only (inspector default).
    case raw
    /// Timestamp, service, level prefix (multi-service / future).
    case structured
}

/// High-performance AppKit-backed log console for terminal logs.
public struct KumaLogConsoleView: NSViewRepresentable {
    public let entries: [LiveLogEntry]
    public let displayMode: LogDisplayMode
    public let isAutoScroll: Bool
    public let wrapsLines: Bool
    public var emptyPlaceholder: String
    public var scrollToBottomRequest: Int
    public var onUserScrolledAwayFromBottom: (() -> Void)?

    public init(
        entries: [LiveLogEntry],
        displayMode: LogDisplayMode = .raw,
        isAutoScroll: Bool = true,
        wrapsLines: Bool = true,
        emptyPlaceholder: String = "No logs available",
        scrollToBottomRequest: Int = 0,
        onUserScrolledAwayFromBottom: (() -> Void)? = nil
    ) {
        self.entries = entries
        self.displayMode = displayMode
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
        context.coordinator.resetRenderState()

        updateTextView(textView, context: context, forceFullRebuild: true)
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let scrollView = nsView as? LogConsoleScrollView,
              let textView = nsView.documentView as? NSTextView else { return }

        context.coordinator.onUserScrolledAwayFromBottom = onUserScrolledAwayFromBottom
        applyLayout(to: textView, scrollView: scrollView)

        let canAppend = context.coordinator.canAppendTail(entries: entries)
        let forceRebuild = !canAppend
        updateTextView(textView, context: context, forceFullRebuild: forceRebuild)

        // #region agent log
        let textLen = textView.string.count
        if entries.isEmpty || (entries.count > 0 && textLen < 8) || forceRebuild {
            AgentDebugLog.write(
                hypothesisId: entries.isEmpty ? "A" : (textLen < 8 ? "E" : "C"),
                location: "KumaLogConsoleView.updateNSView",
                message: "console_update",
                data: [
                    "entryCount": "\(entries.count)",
                    "canAppend": "\(canAppend)",
                    "forceRebuild": "\(forceRebuild)",
                    "textLen": "\(textLen)",
                    "isAutoScroll": "\(isAutoScroll)",
                    "lastRendered": "\(context.coordinator.lastRenderedCount)"
                ]
            )
        }
        // #endregion

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
            let formatted = LogRowFormatter.fullDocument(for: entries, mode: displayMode)
            textStorage.setAttributedString(formatted)
            context.coordinator.lastRenderedCount = entries.count
            context.coordinator.firstEntryID = entries.first?.id
            context.coordinator.lastEntriesID = entries.last?.id
            context.coordinator.contentDirty = true
            return
        }

        let startIndex = context.coordinator.lastRenderedCount
        guard startIndex < entries.count else { return }

        let appendBlock = LogRowFormatter.appendBlock(entries: entries, from: startIndex, mode: displayMode)
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

        private weak var scrollView: LogConsoleScrollView?
        private weak var textView: NSTextView?
        private var isProgrammaticScroll = false

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

        private var lastBoundsLogMs: Int = 0

        func handleBoundsChange() {
            guard !isProgrammaticScroll else { return }
            guard let scrollView, let textView else { return }
            let pinned = scrollView.isPinnedToBottom(textView: textView)
            // #region agent log
            let nowMs = Int(Date().timeIntervalSince1970 * 1000)
            if !pinned, nowMs - lastBoundsLogMs > 400 {
                lastBoundsLogMs = nowMs
                AgentDebugLog.write(
                    hypothesisId: "D",
                    location: "KumaLogConsoleView.handleBoundsChange",
                    message: "scroll_not_pinned",
                    data: [
                        "textLen": "\(textView.string.count)",
                        "visibleMaxY": "\(scrollView.contentView.documentVisibleRect.maxY)",
                        "docHeight": "\(textView.bounds.height)"
                    ]
                )
            }
            // #endregion
            if !pinned {
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

    static func fullDocument(for entries: [LiveLogEntry], mode: LogDisplayMode) -> NSMutableAttributedString {
        let formatted = NSMutableAttributedString()
        for (index, entry) in entries.enumerated() {
            formatted.append(row(entry, mode: mode, appendNewline: index < entries.count - 1))
        }
        return formatted
    }

    static func appendBlock(entries: [LiveLogEntry], from startIndex: Int, mode: LogDisplayMode) -> NSMutableAttributedString {
        let block = NSMutableAttributedString()
        if startIndex > 0 {
            block.append(NSAttributedString(string: "\n", attributes: messageAttributes))
        }
        for index in startIndex..<entries.count {
            block.append(row(entries[index], mode: mode, appendNewline: index < entries.count - 1))
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

    private static func row(_ entry: LiveLogEntry, mode: LogDisplayMode, appendNewline: Bool) -> NSAttributedString {
        switch mode {
        case .raw:
            return NSAttributedString(
                string: entry.message + (appendNewline ? "\n" : ""),
                attributes: msgAttributes
            )
        case .structured:
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
}
