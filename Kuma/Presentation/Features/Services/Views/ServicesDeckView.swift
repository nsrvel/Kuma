import SwiftUI
import UniformTypeIdentifiers

public struct ServicesDeckView: View {
    public let workspaceID: UUID
    public let isStarredOnly: Bool

    @State var viewModel: ServicesDeckViewModel
    @State private var pendingImportBackup: DataPortService.KumaBackup? = nil
    @State private var pendingImportFileName: String = ""
    @State private var alertMessage: String? = nil
    @FocusState private var isSearchFocused: Bool

    @Environment(WorkspaceStore.self) private var workspaceStore

    public init(workspaceID: UUID, isStarredOnly: Bool = false) {
        self.workspaceID = workspaceID
        self.isStarredOnly = isStarredOnly
        _viewModel = State(initialValue: ServicesDeckViewModel(isStarredOnly: isStarredOnly))
    }

    public var body: some View {
        VStack(spacing: 0) {
            contentBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(isStarredOnly ? "Starred Services" : "Services")
        .searchable(text: $viewModel.searchText, isPresented: $isSearchFocused, placement: .toolbar, prompt: "Search services")
        .toolbar {
            toolbarContent()
        }
        .onAppear {
            viewModel.loadWorkspace(workspaceID: workspaceID)
        }
        .onChange(of: workspaceID) { _, newID in
            viewModel.loadWorkspace(workspaceID: newID)
        }
        .onChange(of: isStarredOnly) { _, newStarred in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                viewModel.isStarredOnly = newStarred
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kumaServiceCreated)) { _ in
            viewModel.loadWorkspace(workspaceID: workspaceID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kumaFocusSearch)) { _ in
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .kumaExportWorkspace)) { _ in

            exportCurrentWorkspace()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kumaImportWorkspace)) { _ in
            promptImportFile()
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

    private func exportCurrentWorkspace() {
        let wsName = workspaceStore.workspaces.first(where: { $0.id == workspaceID })?.name ?? "workspace"
        let sanitizedName = wsName.lowercased().replacingOccurrences(of: " ", with: "-")
        let panel = NSSavePanel()
        panel.title = "Export Workspace (\(wsName))"
        panel.nameFieldStringValue = "\(sanitizedName)-services-\(DataPortService.backupDateString).json"
        panel.allowedContentTypes = [.json]

        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    self.performWorkspaceExport(to: url)
                }
            }
            return
        }

        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                self.performWorkspaceExport(to: url)
            }
        }
    }

    private func performWorkspaceExport(to url: URL) {
        Task {
            do {
                let dataPort = DataPortRepository()
                let backup = try await dataPort.exportWorkspace(id: workspaceID)
                let data = try DataPortService.encodeBackup(backup)
                try data.write(to: url)
            } catch {
                alertMessage = "Failed to export workspace: \(error.localizedDescription)"
            }
        }
    }

    private func promptImportFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Services into Workspace"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]

        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    self.processWorkspaceImportUrl(url)
                }
            }
            return
        }

        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                self.processWorkspaceImportUrl(url)
            }
        }
    }

    private func processWorkspaceImportUrl(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let backup = try DataPortService.decodeBackup(from: data)
            self.pendingImportBackup = backup
            self.pendingImportFileName = url.lastPathComponent
        } catch {
            alertMessage = "Failed to read backup file: \(error.localizedDescription)"
        }
    }

    private func executeImport(backup: DataPortService.KumaBackup, selectedServiceIDs: Set<UUID>, resolvedNames: [UUID: String]) {
        Task {
            do {
                let dataPort = DataPortRepository()
                try await dataPort.importIntoWorkspace(
                    targetWorkspaceID: workspaceID,
                    backup: backup,
                    selectedServiceIDs: selectedServiceIDs,
                    resolvedNames: resolvedNames
                )
                viewModel.loadWorkspace(workspaceID: workspaceID)
                workspaceStore.loadFromDatabase()
            } catch {
                alertMessage = "Failed to import services: \(error.localizedDescription)"
            }
        }
    }



    // MARK: - Content Body (Empty State / Cards / Table)

    @ViewBuilder
    private var contentBody: some View {
        if !viewModel.hasInitialLoaded {
            // Clean zero-flicker background while database reads (typically < 2ms)
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
                columns: [GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 16)],
                spacing: 16
            ) {
                ForEach(viewModel.filteredSnapshots) { snapshot in
                    ServiceCardView(
                        snapshot: snapshot,
                        runtime: viewModel.runtimeStates[snapshot.id] ?? ServiceRuntimeState(),
                        isSelected: viewModel.selectedServiceID == snapshot.id,
                        onToggle: { viewModel.toggleService(id: snapshot.id) },
                        onToggleStar: { viewModel.toggleStarred(id: snapshot.id, workspaceID: workspaceID) },
                        onSelect: { viewModel.selectService(snapshot.id) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: viewModel.filteredSnapshots)
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
            onToggleStar: { viewModel.toggleStarred(id: $0, workspaceID: workspaceID) },
            onSelect: { viewModel.selectService($0) }
        )
    }
}

#Preview {
    ServicesDeckView(workspaceID: UUID())
        .frame(width: 900, height: 650)
}
