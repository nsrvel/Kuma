import SwiftUI

public struct ServicesDeckView: View {
    public let workspaceID: UUID

    @State var viewModel = ServicesDeckViewModel()

    public init(workspaceID: UUID) {
        self.workspaceID = workspaceID
    }

    public var body: some View {
        VStack(spacing: 0) {
            contentBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Services")
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search services")
        .toolbar {
            toolbarContent()
        }
        .onAppear {
            viewModel.loadWorkspace(workspaceID: workspaceID)
        }
        .onChange(of: workspaceID) { _, newID in
            viewModel.loadWorkspace(workspaceID: newID)
        }
        .inspector(isPresented: $viewModel.isInspectorPresented) {
            if let selectedID = viewModel.selectedServiceID {
                ServiceInspectorView(
                    serviceID: selectedID,
                    workspaceID: workspaceID,
                    viewModel: viewModel
                )
                .inspectorColumnWidth(
                    min: KumaTheme.Inspector.widthMin,
                    ideal: KumaTheme.Inspector.widthIdeal,
                    max: KumaTheme.Inspector.widthMax
                )
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service to view configuration details and live logs."
                )
                .inspectorColumnWidth(
                    min: KumaTheme.Inspector.widthMin,
                    ideal: KumaTheme.Inspector.widthIdeal,
                    max: KumaTheme.Inspector.widthMax
                )
            }
        }
    }

    // MARK: - Content Body (Empty State / Cards / Table)

    @ViewBuilder
    private var contentBody: some View {
        if viewModel.filteredSnapshots.isEmpty {
            if viewModel.snapshots.isEmpty {
                KumaEmptyStateView(
                    iconName: "square.stack.3d.up.slash",
                    title: "No Services Yet",
                    description: "Create a service to start port-forwarding, container, or shell runs.",
                    actionButtonTitle: "Create Service",
                    action: {}
                )
            } else {
                KumaEmptyStateView(
                    iconName: "magnifyingglass",
                    title: "No Services Found",
                    description: "Try refining your search text or active filter options."
                )
            }
        } else if viewModel.viewMode == .card {
            cardsGrid
        } else {
            tableList
        }
    }

    // MARK: - Grid View Mode

    @ViewBuilder
    private var cardsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 16)],
                spacing: 16
            ) {
                ForEach(viewModel.filteredSnapshots) { snapshot in
                    ServiceCardView(
                        snapshot: snapshot,
                        runtime: viewModel.runtimeStates[snapshot.id] ?? ServiceRuntimeState(),
                        isSelected: viewModel.selectedServiceID == snapshot.id,
                        onToggle: { viewModel.toggleService(id: snapshot.id) },
                        onSelect: { viewModel.selectService(snapshot.id) }
                    )
                }
            }
            .padding(20)
        }
    }

    // MARK: - Table View Mode

    @ViewBuilder
    private var tableList: some View {
        ServiceTableView(
            snapshots: viewModel.filteredSnapshots,
            runtimeStates: viewModel.runtimeStates,
            selectedID: viewModel.selectedServiceID,
            onToggle: { viewModel.toggleService(id: $0) },
            onSelect: { viewModel.selectService($0) }
        )
    }
}

#Preview {
    ServicesDeckView(workspaceID: UUID())
        .frame(width: 900, height: 650)
}
