//
//  KumaCard.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Reusable container providing native macOS glassmorphism, subtle borders, and optional hover feedback.
//

import SwiftUI

public struct KumaCard<Content: View>: View {
    private let padding: CGFloat
    private let isInteractive: Bool
    private let content: Content

    @State private var isHovered: Bool = false

    public init(
        padding: CGFloat = KumaSpacing.md,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.isInteractive = isInteractive
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                    .fill(isHovered && isInteractive ? .ultraThickMaterial : .ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                    .stroke(
                        isHovered && isInteractive ? Color.accentColor.opacity(0.6) : Color(nsColor: .separatorColor),
                        lineWidth: isHovered && isInteractive ? 1.0 : 0.5
                    )
            )
            .onHover { hovering in
                guard isInteractive else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

#Preview {
    VStack(spacing: KumaSpacing.md) {
        KumaCard(isInteractive: true) {
            HStack {
                Text("Interactive Card")
                    .font(KumaFont.heading)
                Spacer()
                Image(systemName: "chevron.right")
            }
        }

        KumaCard(isInteractive: false) {
            Text("Static Card Container")
                .font(KumaFont.body)
        }
    }
    .padding()
    .frame(width: 350)
}
