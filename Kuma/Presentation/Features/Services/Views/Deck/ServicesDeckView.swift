import SwiftUI
import UniformTypeIdentifiers

public struct ServicesDeckView: View {
    public let workspaceID: UUID
    public let isStarredOnly: Bool
    public let filterGroupID: UUID?

    @State var viewModel: ServicesDeckViewModel
    @State var pendingImportBackup: DataPortService.KumaBackup? = nil
    @State var pendingImportFileName: String = ""
    @State var alertMessage: String? = nil
    @State private var isSearching: Bool = false

    @Environment(WorkspaceStore.self) var workspaceStore

    public init(workspaceID: UUID, isStarredOnly: Bool = false, filterGroupID: UUID? = nil) {
        self.workspaceID = workspaceID
        self.isStarredOnly = isStarredOnly
        self.filterGroupID = filterGroupID
        _viewModel = State(initialValue: ServicesDeckViewModel(isStarredOnly: isStarredOnly, filterGroupID: filterGroupID))
    }

    public var body: some View {
        VStack(spacing: 0) {
            contentBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(isStarredOnly ? "Starred Services" : "Services")
        .searchable(text: $viewModel.searchText, isPresented: $isSearching, placement: .toolbar, prompt: "Search services")
        .toolbar {
            toolbarContent()
        }
        .task(id: workspaceID) {
            viewModel.loadWorkspace(workspaceID: workspaceID)
        }
        .onChange(of: isStarredOnly) { _, newStarred in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                viewModel.isStarredOnly = newStarred
            }
        }
        .onChange(of: filterGroupID) { _, newGroupID in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                viewModel.filterGroupID = newGroupID
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .kumaServiceCreated) {
                viewModel.loadWorkspace(workspaceID: workspaceID)
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .kumaServiceUpdated) {
                viewModel.loadWorkspace(workspaceID: workspaceID)
            }
        }
        .task {
            for await notif in NotificationCenter.default.notifications(named: .kumaServiceStateChanged) {
                if let serviceID = notif.object as? UUID, let state = notif.userInfo?["state"] as? ServiceState {
                    viewModel.runtimeStates[serviceID] = ServiceRuntimeState(status: state, isLoading: false)
                }
            }
        }
        .task {
            for await notif in NotificationCenter.default.notifications(named: .kumaServiceDeleted) {
                viewModel.loadWorkspace(workspaceID: workspaceID)
                if let deletedID = notif.object as? UUID, viewModel.selectedServiceID == deletedID {
                    viewModel.selectedServiceID = nil
                    viewModel.isInspectorPresented = false
                }
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .kumaGroupsUpdated) {
                viewModel.loadWorkspace(workspaceID: workspaceID)
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .kumaFocusSearch) {
                isSearching = true
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .kumaExportWorkspace) {
                exportCurrentWorkspace()
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .kumaImportWorkspace) {
                promptImportFile()
            }
        }
        .sheet(item: $pendingImportBackup) { backup in
            let wsName = workspaceStore.workspaces.first(where: { $0.id == workspaceID })?.name ?? "Workspace"
            let existingNames = Set(viewModel.snapshots.map { $0.name.lowercased() })
            WorkspaceImportPreviewSheet(
                backup: backup,
                fileName: pendingImportFileName,
                targetWorkspaceName: wsName,
                targetWorkspaceID: workspaceID,
                existingServiceNames: existingNames,
                onConfirmImport: { selectedServiceIDs, resolvedNames in
                    executeImport(backup: backup, selectedServiceIDs: selectedServiceIDs, resolvedNames: resolvedNames)
                }
            )
        }
        .alert("Workspace Data", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog(
            "Delete Service?",
            isPresented: Binding(
                get: { viewModel.servicePendingDeletion != nil },
                set: { if !$0 { viewModel.servicePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Service", role: .destructive) {
                viewModel.confirmDeletePendingService(workspaceID: workspaceID)
            }
            Button("Cancel", role: .cancel) {
                viewModel.servicePendingDeletion = nil
            }
        } message: {
            Text("This action cannot be undone. '\(viewModel.servicePendingDeletion?.name ?? "Service")' and all associated runner configurations will be permanently deleted.")
        }
        .inspector(isPresented: $viewModel.isInspectorPresented) {
            if let selectedID = viewModel.selectedServiceID {
                ServiceInspectorView(
                    serviceID: selectedID,
                    workspaceID: workspaceID
                )
                .id(selectedID)
                .inspectorColumnWidth(
                    min: KumaTheme.Inspector.widthMin,
                    ideal: KumaTheme.Inspector.widthIdeal,
                    max: KumaTheme.Inspector.widthMax
                )
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service to view configuration details."
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
        if !viewModel.hasInitialLoaded {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredSnapshots.isEmpty {
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
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: viewModel.filterVersion)
            .padding(16)
        }
    }

    // MARK: - Table View Mode

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

#Preview {
    ServicesDeckView(workspaceID: UUID())
        .frame(width: 900, height: 650)
}
