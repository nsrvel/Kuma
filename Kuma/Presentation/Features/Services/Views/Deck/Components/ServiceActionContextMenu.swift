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

            Divider()

            // 2. Open Inspector Details
            Button {
                onSelect()
            } label: {
                Label("Open Details", systemImage: "sidebar.right")
            }

            // 3. Star / Unstar
            Button {
                onToggleStar()
            } label: {
                if snapshot.isStarred {
                    Label("Unstar", systemImage: "star.slash")
                } else {
                    Label("Star", systemImage: "star")
                }
            }
        }
    }
}
