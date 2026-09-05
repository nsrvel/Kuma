import SwiftUI
import AppKit

// MARK: - KumaCodeEditor

/// Professional Code & Configuration (YAML/Shell/JSON) Editor for Kuma.
/// Features:
/// - Direct `Return` / `Enter` for newlines
/// - `Tab` key inserts 2 spaces indentation (does not lose focus)
/// - Pure monospaced typography with syntax formatting guards (no smart quotes/dashes)
/// - Clean dark terminal viewport with line number guides & integrated clipboard copy
public struct KumaCodeEditor: View {
    public let label: String
    @Binding public var code: String
    public var placeholder: String
    public var minHeight: CGFloat
    public var maxHeight: CGFloat?
    public var isReadOnly: Bool

    @FocusState private var isFocused: Bool
    @State private var copiedRecently: Bool = false

    public init(
        label: String = "",
        code: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 140,
        maxHeight: CGFloat? = nil,
        isReadOnly: Bool = false
    ) {
        self.label = label
        self._code = code
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.isReadOnly = isReadOnly
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KumaSpacing.xs) {
            if !label.isEmpty {
                HStack {
                    Text(label)
                        .font(KumaFont.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !code.isEmpty {
                        Button {
                            copyCode()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: copiedRecently ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9))
                                Text(copiedRecently ? "Copied" : "Copy")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                KumaNativeCodeTextView(
                    text: $code,
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                    isReadOnly: isReadOnly,
                    isFocused: $isFocused
                )
                .frame(minHeight: minHeight, maxHeight: maxHeight)

                if code.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(nsColor: .placeholderTextColor))
                        .padding(.leading, 7)
                        .padding(.top, 7)
                        .allowsHitTesting(false)
                }
            }
            .padding(2)
            .background(KumaColors.inputBackground.opacity(0.8), in: RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                    .stroke(
                        isFocused ? Color.accentColor : KumaColors.inputBorder,
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
            )
        }
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation { copiedRecently = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { copiedRecently = false }
        }
    }
}

// MARK: - KumaNativeCodeTextView

private struct KumaNativeCodeTextView: NSViewRepresentable {
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let isReadOnly: Bool
    @FocusState.Binding var isFocused: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = CodeNSTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0.0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 6, height: 6)

        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isEditable = !isReadOnly
        textView.isSelectable = true

        // Developer code settings (disable autocorrect / smart punctuation, match native text field colors)
        textView.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.string = text
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        textView.isEditable = !isReadOnly
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: KumaNativeCodeTextView

        init(_ parent: KumaNativeCodeTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }
    }
}

// MARK: - CodeNSTextView (Custom Key Events for Tab Indentation)

private final class CodeNSTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        // Tab key: Insert 2 spaces instead of shifting UI focus
        if event.keyCode == 48 { // KeyCode 48 is Tab
            self.insertText("  ", replacementRange: self.selectedRange())
            return
        }
        super.keyDown(with: event)
    }
}
