import SwiftUI

extension View {
    @ViewBuilder
    public func serviceTableContextMenu(
        snapshots: [ServiceCardSnapshot],
        runtimeStates: [UUID: ServiceRuntimeState],
        groups: [ServiceGroup],
        handlers: ServiceTableActionHandlers
    ) -> some View {
        self.contextMenu(forSelectionType: UUID.self) { selectedIDs in
            if let firstID = selectedIDs.first,
               let snapshot = snapshots.first(where: { $0.id == firstID }) {
                let runtime = runtimeStates[snapshot.id] ?? .idle
                ServiceActionContextMenu(
                    snapshot: snapshot,
                    runtime: runtime,
                    groups: groups,
                    onToggle: { handlers.onToggle(snapshot.id) },
                    onRestart: { handlers.onRestart(snapshot.id) },
                    onSwitchProvider: { provID in handlers.onSwitchProvider(snapshot.id, provID) },
                    onToggleStar: { handlers.onToggleStar(snapshot.id) },
                    onToggleDisabled: { handlers.onToggleDisabled(snapshot.id) },
                    onToggleGroup: { groupID in handlers.onToggleGroup(snapshot.id, groupID) },
                    onDuplicate: { handlers.onDuplicate(snapshot.id) },
                    onCopyConfig: { handlers.onCopyConfig(snapshot.id) },
                    onDelete: { handlers.onDelete(snapshot.id) },
                    onSelect: { handlers.onSelect(snapshot.id) }
                )
            }
        } primaryAction: { selectedIDs in
            if let firstID = selectedIDs.first {
                handlers.onSelect(firstID)
            }
        }
    }
}
