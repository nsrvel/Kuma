import SwiftUI

public struct WorkspaceSwitcherPopover: View {
    @Bindable var store: WorkspaceStore
    @Binding var isPresented: Bool

    @State private var isHoveringActiveSettings = false

    public init(store: WorkspaceStore, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Active Workspace Container Box (Content-First & Instant Context)
            if let activeWS = store.activeWorkspace {
                HStack(spacing: 10) {
                    WorkspaceAvatarView(workspace: activeWS, size: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(activeWS.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)

                        Text("Active Workspace")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    // Direct Settings Gear Button (Clean 1-Click Action)
                    Button {
                        isPresented = false
                        DispatchQueue.main.async {
                            store.workspaceToEdit = activeWS
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.primary.opacity(isHoveringActiveSettings ? 1.0 : 0.5))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringActiveSettings = $0 }
                    .help("Workspace Settings")
                }
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .contextMenu {
                    Button {
                        isPresented = false
                        DispatchQueue.main.async {
                            store.workspaceToEdit = activeWS
                        }
                    } label: {
                        Label("Settings…", systemImage: "gearshape")
                    }

                    if store.workspaces.count > 1 {
                        Divider()

                        Button(role: .destructive) {
                            isPresented = false
                            DispatchQueue.main.async {
                                AlertService.shared.confirmDelete(
                                    title: "Delete Workspace?",
                                    message: "All services and configurations in “\(activeWS.name)” will be permanently deleted. This action cannot be undone.",
                                    onConfirm: {
                                        store.deleteWorkspace(activeWS)
                                    }
                                )
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            // Inactive Workspaces (Compact Scrollable List)
            let inactiveWS = store.workspaces.filter { $0.id != store.selectedWorkspaceId }
            if !inactiveWS.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 2) {
                        ForEach(Array(inactiveWS.enumerated()), id: \.element.id) { index, ws in
                            let fullIndex = (store.workspaces.firstIndex(where: { $0.id == ws.id }) ?? index) + 1
                            InactiveWorkspaceRow(
                                workspace: ws,
                                shortcutIndex: fullIndex <= 9 ? fullIndex : nil,
                                canDelete: store.workspaces.count > 1,
                                onSelect: {
                                    store.selectWorkspace(ws)
                                    isPresented = false
                                },
                                onEdit: {
                                    isPresented = false
                                    DispatchQueue.main.async {
                                        store.workspaceToEdit = ws
                                    }
                                },
                                onDelete: {
                                    isPresented = false
                                    DispatchQueue.main.async {
                                        AlertService.shared.confirmDelete(
                                            title: "Delete Workspace?",
                                            message: "All services and configurations in “\(ws.name)” will be permanently deleted. This action cannot be undone.",
                                            onConfirm: {
                                                store.deleteWorkspace(ws)
                                            }
                                        )
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(maxHeight: 220)
                .padding(.top, 4)
            }

            // Crisp Subtle Divider
            KumaDivider(opacity: 0.08, verticalPadding: 6, horizontalPadding: 12)

            // "New Workspace…" action button at the bottom (Exact V3 Padding & Metrics)
            BottomActionButton(title: "New Workspace…") {
                isPresented = false
                DispatchQueue.main.async {
                    store.showCreateSheet = true
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(width: 275)
    }
}

struct InactiveWorkspaceRow: View {
    let workspace: Workspace
    let shortcutIndex: Int?
    let canDelete: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isHoveringGear = false

    var body: some View {
        HStack(spacing: 0) {
            // Clickable area to switch workspace
            HStack(spacing: 10) {
                WorkspaceAvatarView(workspace: workspace, size: 24)

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
                    .transition(.opacity)
                    .help("Workspace Settings")
                } else if let shortcutIndex {
                    Text("⌘\(shortcutIndex)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .frame(width: 28, height: 24)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
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
    WorkspaceSwitcherPopover(
        store: WorkspaceStore(initialWorkspaces: [
            Workspace(name: "Default Workspace"),
            Workspace(name: "Staging Backend"),
            Workspace(name: "Production Cluster")
        ]),
        isPresented: .constant(true)
    )
}
