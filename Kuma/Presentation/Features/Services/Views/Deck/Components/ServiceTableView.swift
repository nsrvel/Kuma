import SwiftUI

/// Ultra-polished native macOS Table view for Services deck.
/// Features 1:1 gradient provider icons matching ServiceCardView, monospaced configs,
/// interactive port chips, live status pills, and context menu actions via an ellipsis button.
public struct ServiceTableView: View {
    public let snapshots: [ServiceCardSnapshot]
    public let runtimeStates: [UUID: ServiceRuntimeState]
    public let selectedID: UUID?
    public var groups: [ServiceGroup] = []

    public var onToggle: (UUID) -> Void
    public var onRestart: (UUID) -> Void
    public var onSwitchProvider: (UUID, UUID) -> Void
    public var onToggleStar: (UUID) -> Void
    public var onToggleDisabled: (UUID) -> Void
    public var onToggleGroup: (UUID, UUID) -> Void
    public var onDuplicate: (UUID) -> Void
    public var onCopyConfig: (UUID) -> Void
    public var onDelete: (UUID) -> Void
    public var onSelect: (UUID) -> Void

    @State private var selection: Set<UUID> = []

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
        self.snapshots = snapshots
        self.runtimeStates = runtimeStates
        self.selectedID = selectedID
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
        Table(snapshots, selection: $selection) {
            // MARK: 1. Service Identity (Icon + Star + Name)
            TableColumn("Name") { snapshot in
                let runtime = runtimeStates[snapshot.id] ?? .idle

                HStack(spacing: 9) {
                    // Provider Gradient Icon (Exact match to Card & Inspector styling)
                    ZStack {
                        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                            .fill(
                                snapshot.isDisabled
                                ? LinearGradient(colors: [Color.secondary.opacity(0.18), Color.secondary.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : snapshot.providerCategory.gradient
                            )
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.black.opacity(snapshot.isDisabled ? 0.0 : 0.12), radius: 1, y: 0.5)

                        ProviderBrandIcon(category: snapshot.providerCategory, size: 12.5)
                            .foregroundStyle(snapshot.isDisabled ? Color.secondary : Color.white)
                    }

                    HStack(spacing: 5) {
                        Text(snapshot.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(snapshot.isDisabled ? .secondary : .primary)
                            .lineLimit(1)

                        if snapshot.isStarred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(Color.yellow)
                        }

                        if snapshot.isDisabled {
                            Text("disabled")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(snapshot.id) }
                .contextMenu {
                    ServiceActionContextMenu(
                        snapshot: snapshot,
                        runtime: runtime,
                        groups: groups,
                        onToggle: { onToggle(snapshot.id) },
                        onRestart: { onRestart(snapshot.id) },
                        onSwitchProvider: { provID in onSwitchProvider(snapshot.id, provID) },
                        onToggleStar: { onToggleStar(snapshot.id) },
                        onToggleDisabled: { onToggleDisabled(snapshot.id) },
                        onToggleGroup: { groupID in onToggleGroup(snapshot.id, groupID) },
                        onDuplicate: { onDuplicate(snapshot.id) },
                        onCopyConfig: { onCopyConfig(snapshot.id) },
                        onDelete: { onDelete(snapshot.id) },
                        onSelect: { onSelect(snapshot.id) }
                    )
                }
            }
            .width(min: 160, ideal: 220)

            // MARK: 2. Provider (Standard Clean Text)
            TableColumn("Provider") { snapshot in
                Text(snapshot.providerCategory.sidebarLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(snapshot.id) }
            }
            .width(ideal: 90)

            // MARK: 3. Ports (Interactive Port Chips)
            TableColumn("Ports") { snapshot in
                Group {
                    if snapshot.portDisplays.isEmpty {
                        ServiceNonPortBadge(category: snapshot.providerCategory)
                    } else {
                        PortChipsView(ports: snapshot.portDisplays)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(snapshot.id) }
            }
            .width(ideal: 110)

            // MARK: 4. Status (Polished Capsule Pill)
            TableColumn("Status") { snapshot in
                let runtime = runtimeStates[snapshot.id] ?? .idle
                ServiceStatusObserver(state: runtime, isDisabled: snapshot.isDisabled)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(snapshot.id) }
            }
            .width(ideal: 90)

            // MARK: 5. Actions (Ellipsis Menu Button)
            TableColumn("") { snapshot in
                let runtime = runtimeStates[snapshot.id] ?? .idle

                Menu {
                    ServiceActionContextMenu(
                        snapshot: snapshot,
                        runtime: runtime,
                        groups: groups,
                        onToggle: { onToggle(snapshot.id) },
                        onRestart: { onRestart(snapshot.id) },
                        onSwitchProvider: { provID in onSwitchProvider(snapshot.id, provID) },
                        onToggleStar: { onToggleStar(snapshot.id) },
                        onToggleDisabled: { onToggleDisabled(snapshot.id) },
                        onToggleGroup: { groupID in onToggleGroup(snapshot.id, groupID) },
                        onDuplicate: { onDuplicate(snapshot.id) },
                        onCopyConfig: { onCopyConfig(snapshot.id) },
                        onDelete: { onDelete(snapshot.id) },
                        onSelect: { onSelect(snapshot.id) }
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
                .help("Service actions")
            }
            .width(28)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: UUID.self) { selectedIDs in
            if let firstID = selectedIDs.first,
               let snapshot = snapshots.first(where: { $0.id == firstID }) {
                let runtime = runtimeStates[snapshot.id] ?? .idle
                ServiceActionContextMenu(
                    snapshot: snapshot,
                    runtime: runtime,
                    groups: groups,
                    onToggle: { onToggle(snapshot.id) },
                    onRestart: { onRestart(snapshot.id) },
                    onToggleStar: { onToggleStar(snapshot.id) },
                    onToggleDisabled: { onToggleDisabled(snapshot.id) },
                    onToggleGroup: { groupID in onToggleGroup(snapshot.id, groupID) },
                    onDuplicate: { onDuplicate(snapshot.id) },
                    onCopyConfig: { onCopyConfig(snapshot.id) },
                    onDelete: { onDelete(snapshot.id) },
                    onSelect: { onSelect(snapshot.id) }
                )
            }
        } primaryAction: { selectedIDs in
            if let firstID = selectedIDs.first {
                onSelect(firstID)
            }
        }
        .onChange(of: selection) { _, new in
            if let id = new.first, id != selectedID {
                onSelect(id)
            }
        }
        .onChange(of: selectedID) { _, id in
            if let id { selection = [id] } else { selection = [] }
        }
        .onAppear {
            if let selectedID { selection = [selectedID] }
        }
    }

    private func isMonospaced(_ category: ProviderCategory) -> Bool {
        switch category {
        case .docker, .podman, .kubernetes, .shell, .ssh:
            return true
        default:
            return false
        }
    }
}
