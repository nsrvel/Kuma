import SwiftUI

/// Isolated content body switcher for ServicesDeckView (Empty State, Cards Grid, or Table List).
public struct ServicesDeckContentBodyView: View {
    public let viewModel: ServicesDeckViewModel
    public let isStarredOnly: Bool
    public let deckActions: ServiceDeckActions

    public init(
        viewModel: ServicesDeckViewModel,
        isStarredOnly: Bool,
        deckActions: ServiceDeckActions
    ) {
        self.viewModel = viewModel
        self.isStarredOnly = isStarredOnly
        self.deckActions = deckActions
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
            ServiceDeckTableSection(viewModel: viewModel, actions: deckActions)
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
            LazyVGrid(columns: deckGridColumns, spacing: KumaTheme.Deck.gutter) {
                ForEach(viewModel.filteredSnapshots) { snapshot in
                    ServiceCardRow(
                        snapshot: snapshot,
                        isSelected: viewModel.selectedServiceID == snapshot.id
                    )
                }
            }
            .animation(nil, value: viewModel.filterVersion)
            .padding(KumaTheme.Deck.gridPadding)
        }
    }

    private var deckGridColumns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: KumaTheme.Deck.cardMinWidth,
                    maximum: KumaTheme.Deck.cardMaxWidth
                ),
                spacing: KumaTheme.Deck.gutter
            ),
        ]
    }
}

#Preview {
    let vm = ServicesDeckViewModel(userDefaults: UserDefaults(suiteName: "deck-preview")!)
    vm.snapshots = [
        ServiceCardSnapshot(id: UUID(), name: "Preview", providerCategory: .shell),
    ]
    vm.hasInitialLoaded = true
    let actions = vm.makeDeckActions(workspaceID: UUID())
    return ServicesDeckContentBodyView(viewModel: vm, isStarredOnly: false, deckActions: actions)
        .environment(\.serviceDeckActions, actions)
        .environment(ServiceStateStore())
        .frame(width: 600, height: 400)
}
