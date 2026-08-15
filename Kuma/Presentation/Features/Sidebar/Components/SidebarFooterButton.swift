//
//  SidebarFooterButton.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% Pixel-Perfect Match with Kuma V3 SidebarFooterButton.
//

import SwiftUI

public struct SidebarFooterButton: View {
    public let icon: String
    public let tooltip: String
    public let action: () -> Void

    @State private var isHovering = false

    public init(icon: String, tooltip: String, action: @escaping () -> Void) {
        self.icon = icon
        self.tooltip = tooltip
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
                .imageScale(.medium)
                .foregroundStyle(isHovering ? Color.primary : Color.secondary)
                .frame(width: 24, height: 24)
                .background(isHovering ? Color.secondary.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovering = $0 }
    }
}
