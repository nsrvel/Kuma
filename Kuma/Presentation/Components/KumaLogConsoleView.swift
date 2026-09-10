import SwiftUI
import AppKit

/// High-performance AppKit-backed log console for terminal logs.
/// Capable of rendering tens of thousands of log lines with 120fps smooth scrolling,
/// zero memory bloat, native multi-line text selection, and auto-scrolling.
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
        context.coordinator.lastRenderedCount = 0

        updateTextView(textView, context: context)
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        let currentCount = entries.count
        let lastCount = context.coordinator.lastRenderedCount

        if currentCount != lastCount || context.coordinator.lastEntriesID != entries.last?.id {
            updateTextView(textView, context: context)
        }

        if isAutoScroll {
            context.coordinator.scrollToBottom(textView: textView, in: nsView)
        }
    }

    private func updateTextView(_ textView: NSTextView, context: Context) {
        context.coordinator.lastRenderedCount = entries.count
        context.coordinator.lastEntriesID = entries.last?.id

        guard let textStorage = textView.textStorage else { return }

        if entries.isEmpty {
            let attrString = NSAttributedString(
                string: emptyPlaceholder,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            textStorage.setAttributedString(attrString)
            return
        }

        let formatted = NSMutableAttributedString()
        let timestampFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        let nameFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        let levelFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
        let msgFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let timeColor = NSColor.secondaryLabelColor.withAlphaComponent(0.65)
        let nameColor = NSColor.controlAccentColor
        let msgColor = NSColor.labelColor.withAlphaComponent(0.92)

        for (index, entry) in entries.enumerated() {
            let row = NSMutableAttributedString()

            // Timestamp: 12:34:56
            row.append(NSAttributedString(
                string: "\(entry.timestamp) ",
                attributes: [.font: timestampFont, .foregroundColor: timeColor]
            ))

            // Service Name (if available)
            if !entry.serviceName.isEmpty {
                row.append(NSAttributedString(
                    string: "[\(entry.serviceName)] ",
                    attributes: [.font: nameFont, .foregroundColor: nameColor]
                ))
            }

            // Level: INFO / WARN / ERR
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

            // Message
            row.append(NSAttributedString(
                string: entry.message + (index < entries.count - 1 ? "\n" : ""),
                attributes: [.font: msgFont, .foregroundColor: msgColor]
            ))

            formatted.append(row)
        }

        textStorage.setAttributedString(formatted)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator: NSObject {
        var lastRenderedCount: Int = 0
        var lastEntriesID: UUID? = nil
        private var isScrolling: Bool = false

        func scrollToBottom(textView: NSTextView, in scrollView: NSScrollView) {
            guard !isScrolling else { return }
            isScrolling = true
            DispatchQueue.main.async { [weak self, weak textView] in
                defer { self?.isScrolling = false }
                guard let textView else { return }
                let length = textView.string.utf16.count
                if length > 0 {
                    textView.scrollRangeToVisible(NSRange(location: length, length: 0))
                }
            }
        }
    }
}
