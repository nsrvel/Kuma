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
                // Transparent Multi-line Text Area
                TextEditor(text: $value)
                    .font(isMonospaced ? .system(size: 11.5, weight: .regular, design: .monospaced) : KumaFont.body)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: minHeight, maxHeight: maxHeight)

                    .onKeyPress(.tab) {
                        NSApp.keyWindow?.selectNextKeyView(nil)
                        return .handled
                    }
                    .onKeyPress(keys: [.tab], phases: .down) { press in
                        if press.modifiers.contains(.shift) {
                            NSApp.keyWindow?.selectPreviousKeyView(nil)
                            return .handled
                        } else {
                            NSApp.keyWindow?.selectNextKeyView(nil)
                            return .handled
                        }
                    }

                // Native Muted Placeholder (precisely aligned with NSTextView line 1 container inset)
                if value.isEmpty {
                    Text(placeholder)
                        .font(KumaFont.body)
                        .foregroundStyle(Color(nsColor: .placeholderTextColor))
                        .padding(.leading, 5)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }
            .padding(KumaSpacing.sm)
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
