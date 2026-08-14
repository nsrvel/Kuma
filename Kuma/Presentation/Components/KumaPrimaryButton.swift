//
//  KumaPrimaryButton.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Crafted macOS-native Primary CTA button following Apple HIG with tactile press & subtle elevation.
//

import SwiftUI

/// Custom ButtonStyle providing Apple-grade tactile press state and crisp depth.
public struct KumaPrimaryButtonStyle: ButtonStyle {
    private let maxWidth: CGFloat?

    public init(maxWidth: CGFloat? = 220) {
        self.maxWidth = maxWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KumaFont.heading)
            .foregroundStyle(.white)
            .frame(maxWidth: maxWidth)
            .padding(.vertical, 9)
            .padding(.horizontal, KumaSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                    .fill(Color.accentColor)
                    .brightness(configuration.isPressed ? -0.08 : 0)
            )
            // Crisp 0.5pt macOS stroke highlight
            .overlay(
                RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.05 : 0.15), lineWidth: 0.5)
            )
            // Subtle native drop shadow (depth without neon glow)
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.05 : 0.12),
                radius: configuration.isPressed ? 1 : 3,
                x: 0,
                y: configuration.isPressed ? 0.5 : 1.5
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

public struct KumaPrimaryButton: View {
    private let title: String
    private let icon: String?
    private let maxWidth: CGFloat?
    private let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        maxWidth: CGFloat? = 220,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.maxWidth = maxWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: KumaSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
            }
        }
        .buttonStyle(KumaPrimaryButtonStyle(maxWidth: maxWidth))
        .keyboardShortcut(.defaultAction)
    }
}

#Preview {
    VStack(spacing: KumaSpacing.lg) {
        KumaPrimaryButton("Continue", icon: "arrow.right") {}
        KumaPrimaryButton("Get Started") {}
    }
    .padding()
    .frame(width: 320)
}
