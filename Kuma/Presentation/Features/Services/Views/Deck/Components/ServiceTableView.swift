import SwiftUI

/// Ultra-polished native macOS Table view for Services deck.
/// Features 1:1 gradient provider icons matching ServiceCardView, monospaced configs,
/// interactive port chips, live status pills, and context menu actions via an ellipsis button.
public struct ServiceTableView: View {
    public let snapshots: [ServiceCardSnapshot]
    public let runtimeStates: [UUID: ServiceRuntimeState]
    public let selectedID: UUID?
    public var groups: [ServiceGroup] = []

    public let handlers: ServiceTableActionHandlers
    @State private var selection: Set<UUID> = []

    public init(
        snapshots: [ServiceCardSnapshot],
        runtimeStates: [UUID: ServiceRuntimeState],
        selectedID: UUID?,
        groups: [ServiceGroup] = [],
        handlers: ServiceTableActionHandlers
    ) {
        self.snapshots = snapshots
        self.runtimeStates = runtimeStates
        self.selectedID = selectedID
        self.groups = groups
        self.handlers = handlers
    }

    public init(
        snapshots: [ServiceCardSnapshot],
        runtimeStates: [UUID: ServiceRuntimeState],
        selectedID: UUID?,
        groups: [ServiceGroup] = [],
        onToggle: @escaping (UUID) -> Void,
        onRestart: @escaping (UUID) -> Void = { _ in },
        onSwitchProvider: @escaping (UUID, UUID) -> Void = { _, _ in },
        onToggleStar: @escaping (UUID) -> Void = { _ in },
        onToggleDisabled: @escaping (UUID) -> Void = { _ in },
        onToggleGroup: @escaping (UUID, UUID) -> Void = { _, _ in },
        onDuplicate: @escaping (UUID) -> Void = { _ in },
        onCopyConfig: @escaping (UUID) -> Void = { _ in },
        onDelete: @escaping (UUID) -> Void = { _ in },
        onSelect: @escaping (UUID) -> Void
    ) {
        self.init(
            snapshots: snapshots,
            runtimeStates: runtimeStates,
            selectedID: selectedID,
            groups: groups,
            handlers: ServiceTableActionHandlers(
                onToggle: onToggle, onRestart: onRestart, onSwitchProvider: onSwitchProvider,
                onToggleStar: onToggleStar, onToggleDisabled: onToggleDisabled, onToggleGroup: onToggleGroup,
                onDuplicate: onDuplicate, onCopyConfig: onCopyConfig, onDelete: onDelete, onSelect: onSelect
            )
        )
    }

    public var body: some View {
        Table(snapshots, selection: $selection) {
            // MARK: 1. Service Identity (Icon + Star + Name)
            TableColumn("Name") { snapshot in
                ServiceTableNameCell(
                    snapshot: snapshot,
                    onSelect: handlers.onSelect
                )
            }
            .width(min: 160, ideal: 220)

            // MARK: 2. Provider (Standard Clean Text)
            TableColumn("Provider") { snapshot in
                Text(snapshot.providerCategory.sidebarLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture { handlers.onSelect(snapshot.id) }
            }
            .width(ideal: 90)

            // MARK: 3. Ports (Interactive Port Chips)
            TableColumn("Ports") { snapshot in
                ServiceTablePortsCell(snapshot: snapshot, onSelect: handlers.onSelect)
            }
            .width(ideal: 110)

            // MARK: 4. Status (Polished Capsule Pill)
            TableColumn("Status") { snapshot in
                let runtime = runtimeStates[snapshot.id] ?? .idle
                ServiceStatusObserver(state: runtime, isDisabled: snapshot.isDisabled)
                    .contentShape(Rectangle())
                    .onTapGesture { handlers.onSelect(snapshot.id) }
            }
            .width(ideal: 90)

            // MARK: 5. Actions (Ellipsis Menu Button)
            TableColumn("") { snapshot in
                let runtime = runtimeStates[snapshot.id] ?? .idle
                ServiceTableActionsCell(
                    snapshot: snapshot,
                    runtime: runtime,
                    groups: groups,
                    handlers: handlers
                )
            }
            .width(28)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .serviceTableContextMenu(
            snapshots: snapshots,
            runtimeStates: runtimeStates,
            groups: groups,
            handlers: handlers
        )
        .onChange(of: selection) { _, new in
            if let id = new.first, id != selectedID {
                handlers.onSelect(id)
            }
        }
        .onChange(of: selectedID) { _, id in
            if let id { selection = [id] } else { selection = [] }
        }
        .onAppear {
            if let selectedID { selection = [selectedID] }
        }
    }
}
