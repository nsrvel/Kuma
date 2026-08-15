//
//  StatusPillsAndChips.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect StatusPillView and PortChipsView components.
//

import SwiftUI

public struct StatusPillView: View {
    public let text: String
    public let color: Color
    public var showDot: Bool
    public var isGlowing: Bool
    public var isLoading: Bool

    public init(
        text: String,
        color: Color,
        showDot: Bool = true,
        isGlowing: Bool = false,
        isLoading: Bool = false
    ) {
        self.text = text
        self.color = color
        self.showDot = showDot
        self.isGlowing = isGlowing
        self.isLoading = isLoading
    }

    public var body: some View {
        HStack(spacing: 5) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else if showDot {
                ZStack {
                    if isGlowing {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .blur(radius: 1.5)
                    }
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                }
            }
            Text(text)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .fixedSize()
    }
}

public struct PortChipsView: View {
    public let ports: [String]
    public var limit: Int

    public init(ports: [String], limit: Int = 2) {
        self.ports = ports
        self.limit = limit
    }

    public var body: some View {
        let visible = Array(ports.prefix(limit))
        let overflow = ports.count - visible.count

        HStack(spacing: 4) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.primary.opacity(0.03))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                    .fixedSize()
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
        }
    }
}
