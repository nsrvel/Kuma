import SwiftUI

// MARK: - InactiveWorkspaceRow

public struct InactiveWorkspaceRow: View {
    public let workspace: Workspace
    public let shortcutIndex: Int?
    public let canDelete: Bool
    public let onSelect: () -> Void
    public let onEdit: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isHoveringGear = false

    public init(
        workspace: Workspace,
        shortcutIndex: Int?,
        canDelete: Bool,
        onSelect: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.workspace = workspace
        self.shortcutIndex = shortcutIndex
        self.canDelete = canDelete
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Clickable area to switch workspace
            HStack(spacing: 8) {
                WorkspaceAvatarView(workspace: workspace, size: KumaTheme.Sidebar.workspaceIconSize)

                Text(workspace.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            // Shortcut Badge (Idle) transitioning to Settings Gear (Hover)
            ZStack {
                if isHovered {
                    Button(action: onEdit) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(isHoveringGear ? 1.0 : 0.5))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringGear = $0 }
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .help("Workspace Settings")
                } else if let shortcutIndex {
                    Text("⌘\(shortcutIndex)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .animation(.snappy(duration: 0.16, extraBounce: 0), value: isHovered)
            .frame(width: 28, height: 24)
        }
        .padding(.vertical, KumaTheme.Sidebar.rowVerticalPadding)
        .padding(.horizontal, KumaTheme.Sidebar.rowHorizontalPadding)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: KumaTheme.Sidebar.rowCornerRadius, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onSelect()
            } label: {
                Label("Switch to Workspace", systemImage: "arrow.right.circle")
            }

            Button {
                onEdit()
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }

            if canDelete {
                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

#Preview {
    InactiveWorkspaceRow(
        workspace: Workspace(name: "Staging Backend"),
        shortcutIndex: 2,
        canDelete: true,
        onSelect: {},
        onEdit: {},
        onDelete: {}
    )
    .frame(width: 250)
    .padding()
}
