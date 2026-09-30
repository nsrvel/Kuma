import SwiftUI

/// Isolated content body switcher for ServicesDeckView (Empty State, Cards Grid, or Table List).
public struct ServicesDeckContentBodyView: View {
    public let viewModel: ServicesDeckViewModel
    public let workspaceID: UUID
    public let isStarredOnly: Bool

    public init(viewModel: ServicesDeckViewModel, workspaceID: UUID, isStarredOnly: Bool) {
        self.viewModel = viewModel
        self.workspaceID = workspaceID
        self.isStarredOnly = isStarredOnly
    }

    public var body: some View {
        if !viewModel.hasInitialLoaded {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredSnapshots.isEmpty {
            emptyStateView
        } else if viewModel.viewMode == .card {
            cardsGrid
        } else {
            tableList
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if isStarredOnly {
            KumaEmptyStateView(
                iconName: "star.slash",
                title: "No Starred Services",
                description: "Star your most frequently used services from the context menu to access them quickly from here."
            )
        } else if viewModel.snapshots.isEmpty {
            KumaEmptyStateView(
                iconName: "square.stack.3d.up.slash",
                title: "No Services Yet",
                description: "Create a service to start port-forwarding, container, or shell runs.",
                actionButtonTitle: "Create Service",
                action: {
                    NotificationCenter.default.post(name: .kumaCreateServiceRequested, object: nil)
                }
            )
        } else {
            KumaEmptyStateView(
                iconName: "magnifyingglass",
                title: "No Services Found",
                description: "Try refining your search text or active filter options."
            )
        }
    }

    @ViewBuilder
    private var cardsGrid: some View {
        ScrollView {
            LazyVGrid(
                 columns: [GridItem(.adaptive(minimum: 280, maximum: .infinity), spacing: 16)],
                 spacing: 16
            ) {
                ForEach(viewModel.filteredSnapshots) { snapshot in
                    ServiceCardView(
                        snapshot: snapshot,
                        runtime: viewModel.runtimeStates[snapshot.id] ?? .idle,
                        isSelected: viewModel.selectedServiceID == snapshot.id,
                        viewModel: viewModel,
                        workspaceID: workspaceID
                    )
                    .equatable()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: viewModel.filterVersion)
            .padding(16)
        }
    }

    @ViewBuilder
    private var tableList: some View {
        ServiceTableView(
            snapshots: viewModel.filteredSnapshots,
            runtimeStates: viewModel.runtimeStates,
            selectedID: viewModel.selectedServiceID,
            groups: viewModel.groups,
            onToggle: { viewModel.toggleService(id: $0) },
            onRestart: { viewModel.restartService(id: $0) },
            onSwitchProvider: { serviceID, providerID in viewModel.switchProvider(serviceID: serviceID, providerID: providerID, workspaceID: workspaceID) },
            onToggleStar: { viewModel.toggleStarred(id: $0, workspaceID: workspaceID) },
            onToggleDisabled: { viewModel.toggleDisabled(id: $0, workspaceID: workspaceID) },
            onToggleGroup: { serviceID, groupID in viewModel.toggleGroup(serviceID: serviceID, groupID: groupID, workspaceID: workspaceID) },
            onDuplicate: { viewModel.duplicateService(id: $0, workspaceID: workspaceID) },
            onCopyConfig: { viewModel.copyConfig(id: $0) },
            onDelete: { viewModel.promptDeleteService(id: $0) },
            onSelect: { viewModel.selectService($0) }
        )
    }
}
