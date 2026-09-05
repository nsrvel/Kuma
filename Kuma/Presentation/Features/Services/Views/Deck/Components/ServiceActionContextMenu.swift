import SwiftUI
import AppKit

public struct ServiceActionContextMenu: View {
    public let snapshot: ServiceCardSnapshot
    public let runtime: ServiceRuntimeState
    public var groups: [ServiceGroup] = []
    public let onToggle: () -> Void
    public let onRestart: () -> Void
    public let onSwitchProvider: (UUID) -> Void
    public let onToggleStar: () -> Void
    public let onToggleDisabled: () -> Void
    public let onToggleGroup: (UUID) -> Void
    public let onDuplicate: () -> Void
    public let onCopyConfig: () -> Void
    public let onDelete: () -> Void
    public let onSelect: () -> Void

    public init(
        snapshot: ServiceCardSnapshot,
        runtime: ServiceRuntimeState,
        groups: [ServiceGroup] = [],
        onToggle: @escaping () -> Void = {},
        onRestart: @escaping () -> Void = {},
        onSwitchProvider: @escaping (UUID) -> Void = { _ in },
        onToggleStar: @escaping () -> Void = {},
        onToggleDisabled: @escaping () -> Void = {},
        onToggleGroup: @escaping (UUID) -> Void = { _ in },
        onDuplicate: @escaping () -> Void = {},
        onCopyConfig: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {},
        onSelect: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.runtime = runtime
        self.groups = groups
        self.onToggle = onToggle
        self.onRestart = onRestart
        self.onSwitchProvider = onSwitchProvider
        self.onToggleStar = onToggleStar
        self.onToggleDisabled = onToggleDisabled
        self.onToggleGroup = onToggleGroup
        self.onDuplicate = onDuplicate
        self.onCopyConfig = onCopyConfig
        self.onDelete = onDelete
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            // 1. Start / Stop Service
            if snapshot.isDisabled {
                Button {} label: {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(true)
            } else if runtime.status == .running || runtime.status == .starting {
                Button {
                    onToggle()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else {
                Button {
                    onToggle()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
            }

            // 2. Restart
            Button {
                onRestart()
            } label: {
                Label("Restart", systemImage: "arrow.clockwise")
            }
            .disabled(snapshot.isDisabled || runtime.status != .running)

            Divider()

            // 3. Open Details
            Button {
                onSelect()
            } label: {
                Label("Open Details", systemImage: "sidebar.right")
            }

            // 4. Switch Provider Submenu (Always visible for HIG consistency)
            Menu {
                if !snapshot.providerOptions.isEmpty {
                    ForEach(snapshot.providerOptions) { option in
                        Button {
                            onSwitchProvider(option.id)
                        } label: {
                            HStack {
                                Text(option.label)
                                if option.isActive {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } else {
                    Button {} label: {
                        HStack {
                            Text(snapshot.providerCategory.sidebarLabel)
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(true)
                }
            } label: {
                Label("Switch Provider", systemImage: "arrow.triangle.2.circlepath")
            }

            // 5. Groups (Multi-select Toggle Submenu)
            if !groups.isEmpty {
                Menu {
                    ForEach(groups) { group in
                        Button {
                            onToggleGroup(group.id)
                        } label: {
                            HStack {
                                Text(group.name)
                                if snapshot.groupIDs.contains(group.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Groups", systemImage: "folder")
                }
            }

            // 6. Star Toggle
            Button {
                onToggleStar()
            } label: {
                Label("Star", systemImage: snapshot.isStarred ? "star.fill" : "star")
            }

            // 7. Duplicate
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            // 8. Copy Config
            Button {
                onCopyConfig()
            } label: {
                Label("Copy Config", systemImage: "doc.on.doc")
            }

            Divider()

            // 9. Disable / Enable
            Button {
                onToggleDisabled()
            } label: {
                if snapshot.isDisabled {
                    Label("Enable", systemImage: "lock.open.fill")
                } else {
                    Label("Disable", systemImage: "lock.slash.fill")
                }
            }

            // 10. Delete
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
