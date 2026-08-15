//
//  ServicesDeckView.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect Services Deck Stage with Toolbar, Filters, View Modes, and Collapsible Native Inspector.
//

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
                .inspectorColumnWidth(min: 335, ideal: 450, max: 565)
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service to view configuration details and live logs."
                )
                .inspectorColumnWidth(min: 335, ideal: 450, max: 565)
            }
        }
    }

    // MARK: - Content Body (Empty State / Cards / Table)

    @ViewBuilder
    private var contentBody: some View {
        if viewModel.filteredServices.isEmpty {
            if viewModel.services.isEmpty {
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
                columns: [GridItem(.adaptive(minimum: 300, maximum: 380), spacing: 18)],
                spacing: 18
            ) {
                ForEach(viewModel.filteredServices) { service in
                    ServiceCardView(
                        service: service,
                        providerCategory: viewModel.serviceProviders[service.id] ?? .docker,
                        detailDescription: service.description ?? "",
                        portMappings: viewModel.portMappings[service.id] ?? [],
                        isSelected: viewModel.selectedServiceID == service.id,
                        status: viewModel.serviceStates[service.id] ?? .stopped,
                        isLoading: viewModel.loadingServiceIDs.contains(service.id),
                        onToggle: { viewModel.toggleService(service) },
                        onSelect: { viewModel.selectService(service.id) }
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
            services: viewModel.filteredServices,
            portMappings: viewModel.portMappings,
            selectedID: viewModel.selectedServiceID,
            states: viewModel.serviceStates,
            loadingIDs: viewModel.loadingServiceIDs,
            onToggle: { viewModel.toggleService($0) },
            onSelect: { viewModel.selectService($0.id) }
        )
    }
}

#Preview {
    ServicesDeckView(workspaceID: UUID())
        .frame(width: 900, height: 650)
}
