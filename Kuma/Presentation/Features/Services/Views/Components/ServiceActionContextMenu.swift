import SwiftUI

public struct ServiceActionContextMenu: View {
    public let snapshot: ServiceCardSnapshot
    public let runtime: ServiceRuntimeState
    public let onToggle: () -> Void
    public let onToggleStar: () -> Void
    public let onSelect: () -> Void

    public init(
        snapshot: ServiceCardSnapshot,
        runtime: ServiceRuntimeState,
        onToggle: @escaping () -> Void = {},
        onToggleStar: @escaping () -> Void = {},
        onSelect: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.runtime = runtime
        self.onToggle = onToggle
        self.onToggleStar = onToggleStar
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            // 1. Start / Stop
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
                // UI Action: Restart
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

            // 4. Switch Provider (Only shown if available)
            Menu {
                Button {} label: {
                    Label(snapshot.providerCategory.sidebarLabel, systemImage: "checkmark")
                }
            } label: {
                Label("Switch Provider", systemImage: "arrow.triangle.swap")
            }

            // 5. Star / Unstar
            Button {
                onToggleStar()
            } label: {
                if snapshot.isStarred {
                    Label("Unstar", systemImage: "star.slash")
                } else {
                    Label("Star", systemImage: "star")
                }
            }

            Divider()

            // 6. Duplicate
            Button {
                // UI Action: Duplicate service
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            // 7. Copy Config
            Button {
                // UI Action: Copy configuration
            } label: {
                Label("Copy Config", systemImage: "doc.on.doc")
            }

            Divider()

            // 8. Disable / Enable
            if snapshot.isDisabled {
                Button {
                    // UI Action: Enable
                } label: {
                    Label("Enable", systemImage: "lock.open.fill")
                }
            } else {
                Button {
                    // UI Action: Disable
                } label: {
                    Label("Disable", systemImage: "lock.slash.fill")
                }
            }

            // 9. Delete
            Button(role: .destructive) {
                // UI Action: Delete
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
