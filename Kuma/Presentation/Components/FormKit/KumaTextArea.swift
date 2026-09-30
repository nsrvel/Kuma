import SwiftUI
import AppKit

// MARK: - KumaTextArea

/// A multi-line plain text area for descriptions, notes, and multi-line inputs.
/// Follows Kuma Design Tokens (Colors, Radius, Focus Ring, Native Placeholder).
public struct KumaTextArea: View {
    public let label: String
    @Binding public var value: String
    public var placeholder: String
    public var minHeight: CGFloat
    public var maxHeight: CGFloat?
    public var isMonospaced: Bool
    public var error: String?

    @FocusState private var isFocused: Bool

    public init(
        label: String = "",
        value: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 64,
        maxHeight: CGFloat? = nil,
        isMonospaced: Bool = false,
        error: String? = nil
    ) {
        self.label = label
        self._value = value
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.isMonospaced = isMonospaced
        self.error = error
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KumaSpacing.xs) {
            if !label.isEmpty {
                Text(label)
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                KumaNativeTextView(
                    text: $value,
                    isMonospaced: isMonospaced,
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                    isFocused: $isFocused
                )
                .frame(minHeight: minHeight, maxHeight: maxHeight)

                // Native Muted Placeholder
                if value.isEmpty {
                    Text(placeholder)
                        .font(isMonospaced ? .system(size: 11.5, weight: .regular, design: .monospaced) : KumaFont.body)
                        .foregroundStyle(Color(nsColor: .placeholderTextColor))
                        .padding(.leading, 4)
                        .padding(.top, 4)
                        .allowsHitTesting(false)
                }
            }
            .padding(4)
            .background(KumaColors.inputBackground, in: RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                    .stroke(
                        isFocused ? Color.accentColor : KumaColors.inputBorder,
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
            )

            if let error, !error.isEmpty {
                Text(error)
                    .font(KumaFont.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var notes = ""
        @State private var filledNotes = "Local PostgreSQL database for development.\nConnect via psql or DBeaver on port 5432."

        var body: some View {
            VStack(spacing: 20) {
                KumaTextArea(
                    label: "Description / Notes (Empty)",
                    value: $notes,
                    placeholder: "Service purpose or notes..."
                )

                KumaTextArea(
                    label: "Description / Notes (Filled)",
                    value: $filledNotes,
                    placeholder: "Service purpose or notes..."
                )
            }
            .padding()
            .frame(width: 440)
            .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}

// MARK: - KumaNativeTextView

private struct KumaNativeTextView: NSViewRepresentable {
    @Binding var text: String
    let isMonospaced: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    @FocusState.Binding var isFocused: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0.0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 4, height: 4)

        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator

        if isMonospaced {
            textView.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        } else {
            textView.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        }
        textView.textColor = .labelColor
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: KumaNativeTextView

        init(_ parent: KumaNativeTextView) {
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
