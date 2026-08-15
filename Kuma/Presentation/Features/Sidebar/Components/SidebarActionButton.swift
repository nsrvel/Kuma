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
    }
}
