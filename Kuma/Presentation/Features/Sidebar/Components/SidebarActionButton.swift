//
//  SidebarActionButton.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% Pixel-Perfect Match with Kuma V3 SidebarActionButton.
//

import SwiftUI

public struct SidebarActionButton: View {
    public let action: SidebarAction

    @State private var isHovering = false

    public init(action: SidebarAction) {
        self.action = action
    }

    public var body: some View {
        Button {
            action.handler()
        } label: {
            Image(systemName: action.icon)
                .imageScale(.small)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isHovering ? Color.primary : Color.secondary)
                .frame(width: KumaTheme.Sidebar.actionButtonSize, height: KumaTheme.Sidebar.actionButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(action.tooltip)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovering)
    }
}
