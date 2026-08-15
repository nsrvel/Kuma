//
//  KumaFormSection.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Clean Apple HIG form section wrapper with icon, title, subtitle and danger styles.
//

import SwiftUI

// MARK: - KumaFormSection Style

public enum KumaFormSectionStyle {
    case standard
    case danger
}

// MARK: - KumaFormSection

public struct KumaFormSection<Content: View>: View {
    public let icon: String?
    public let title: String?
    public let subtitle: String?
    public let style: KumaFormSectionStyle
    @ViewBuilder public let content: Content

    public init(
        icon: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        style: KumaFormSectionStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KumaSpacing.sm) {
            if icon != nil || !(title?.isEmpty ?? true) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: KumaSpacing.xs) {
                        if let icon {
                            Image(systemName: icon)
                                .font(KumaFont.caption)
                                .foregroundStyle(style == .danger ? Color.red : Color.secondary)
                        }
                        if let title {
                            Text(title.uppercased())
                                .font(KumaFont.captionBold)
                                .foregroundStyle(style == .danger ? Color.red : Color.secondary)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, KumaSpacing.xs)
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
                        style == .danger ? Color.red.opacity(0.2) : Color.primary.opacity(0.08),
                        lineWidth: 0.5
                    )
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        KumaFormSection(icon: "gearshape.fill", title: "General", subtitle: "Manage system preferences") {
            Text("Sample Content Area")
                .font(KumaFont.body)
        }

        KumaFormSection(icon: "exclamationmark.triangle.fill", title: "Danger Zone", style: .danger) {
            Text("Reset data and restart application")
                .font(KumaFont.body)
        }
    }
    .padding()
    .frame(width: 500)
}
