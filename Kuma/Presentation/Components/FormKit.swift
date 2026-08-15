//
//  FormKit.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Core Form Components: KumaFormSection, KumaTextField.
//

import SwiftUI
import AppKit

// MARK: - KumaFormSectionStyle

public enum KumaFormSectionStyle {
    case standard
    case danger
}

// MARK: - KumaFormSection

public struct KumaFormSection<Content: View>: View {
    public let icon: String?
    public let title: String?
    public let style: KumaFormSectionStyle
    @ViewBuilder public let content: Content

    public init(
        icon: String? = nil,
        title: String? = nil,
        style: KumaFormSectionStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.style = style
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KumaSpacing.sm) {
            if icon != nil || !(title?.isEmpty ?? true) {
                HStack(spacing: KumaSpacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(KumaFont.caption)
                            .foregroundStyle(style == .danger ? Color.red.opacity(0.8) : .secondary)
                    }
                    if let title, !title.isEmpty {
                        Text(title)
                            .font(KumaFont.heading)
                            .foregroundStyle(style == .danger ? Color.red.opacity(0.8) : .primary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: KumaSpacing.md) {
                content
            }
            .padding(KumaSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Group {
                            if style == .danger {
                                RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                                    .fill(Color.red.opacity(0.02))
                            }
                        }
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                    .stroke(
                        style == .danger ? Color.red.opacity(0.2) : Color(NSColor.separatorColor).opacity(0.1),
                        lineWidth: 0.5
                    )
            )
        }
    }
}

// MARK: - KumaTextField

public struct KumaTextField: View {
    public let label: String
    @Binding public var value: String
    public var placeholder: String = ""
    public var error: String? = nil
    public var autoFocus: Bool = false
    public var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    public init(
        label: String,
        value: Binding<String>,
        placeholder: String = "",
        error: String? = nil,
        autoFocus: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.label = label
        self._value = value
        self.placeholder = placeholder
        self.error = error
        self.autoFocus = autoFocus
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KumaSpacing.xs) {
            if !label.isEmpty {
                Text(label)
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)
            }

            TextField(placeholder, text: $value)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }
                .padding(KumaSpacing.sm)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: KumaRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                        .stroke(
                            isFocused ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.1),
                            lineWidth: isFocused ? 1.5 : 0.5
                        )
                )

            if let error, !error.isEmpty {
                Text(error)
                    .font(KumaFont.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            if autoFocus {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }
}
