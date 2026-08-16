import SwiftUI

public struct ServiceTableView: View {
    public let snapshots: [ServiceCardSnapshot]
    public let runtimeStates: [UUID: ServiceRuntimeState]
    public let selectedID: UUID?

    public var onToggle: (UUID) -> Void
    public var onToggleStar: (UUID) -> Void
    public var onSelect: (UUID) -> Void

    @State private var selection: Set<UUID> = []

    public init(
        snapshots: [ServiceCardSnapshot],
        runtimeStates: [UUID: ServiceRuntimeState],
        selectedID: UUID?,
        onToggle: @escaping (UUID) -> Void,
        onToggleStar: @escaping (UUID) -> Void = { _ in },
        onSelect: @escaping (UUID) -> Void
    ) {
        self.snapshots = snapshots
        self.runtimeStates = runtimeStates
        self.selectedID = selectedID
        self.onToggle = onToggle
        self.onToggleStar = onToggleStar
        self.onSelect = onSelect
    }

    public var body: some View {
        Table(snapshots, selection: $selection) {
            TableColumn("Name") { snapshot in
                let runtime = runtimeStates[snapshot.id] ?? ServiceRuntimeState()

                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(snapshot.providerCategory.color.gradient)
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.black.opacity(0.06), radius: 1, y: 0.5)

                        Image(systemName: snapshot.providerCategory.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
                            .symbolEffect(.pulse, isActive: runtime.isLoading || runtime.status == .starting)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(snapshot.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.primary)

                            if snapshot.isStarred {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.yellow)
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
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(snapshot.id) }
                .contextMenu {
                    ServiceActionContextMenu(
                        snapshot: snapshot,
                        runtime: runtime,
                        onToggle: { onToggle(snapshot.id) },
                        onToggleStar: { onToggleStar(snapshot.id) },
                        onSelect: { onSelect(snapshot.id) }
                    )
                }
            }

            TableColumn("Configuration") { snapshot in
                Text(snapshot.subtitle.isEmpty ? snapshot.providerCategory.sidebarLabel : snapshot.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .onTapGesture { onSelect(snapshot.id) }
            }

            TableColumn("Ports") { snapshot in
                ScrollView(.horizontal, showsIndicators: false) {
                    PortChipsView(ports: snapshot.portDisplays, limit: 4)
                        .padding(.vertical, 2)
                }
            }

            TableColumn("Status") { snapshot in
                let runtime = runtimeStates[snapshot.id] ?? ServiceRuntimeState()
                ServiceStatusObserver(state: runtime, isDisabled: snapshot.isDisabled)
                    .onTapGesture { onSelect(snapshot.id) }
            }

            TableColumn("") { snapshot in
                let runtime = runtimeStates[snapshot.id] ?? ServiceRuntimeState()

                let isOnBinding = Binding<Bool>(
                    get: { runtime.status == .running || runtime.status == .starting },
                    set: { _ in onToggle(snapshot.id) }
                )

                Toggle("", isOn: isOnBinding)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .disabled(snapshot.isDisabled || runtime.isLoading)
            }
            .width(44)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
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
}
