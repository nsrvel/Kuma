import SwiftUI

public struct ServiceInspectorView: View {
    public let serviceID: UUID
    public let workspaceID: UUID
    @Bindable var viewModel: ServicesDeckViewModel

    @State private var isEditing: Bool = false
    @State private var isLoadingData: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showDeleteProviderConfirmation: Bool = false
    @State private var showAddProviderSheet: Bool = false


    // Raw loaded models
    @State private var service: Service? = nil
    @State private var providers: [Provider] = []
    @State private var activeProviderID: UUID? = nil

    // Draft General Fields
    @State private var draftName: String = ""
    @State private var draftDescription: String = ""
    @State private var draftIsDisabled: Bool = false

    // Draft Active Provider Specific Fields (Lazy VM)
    @State private var draftProviderLabel: String = ""
    @State private var kubeConfigVM: KubeConfigViewModel? = nil
    @State private var draftKubeNamespace: String = ""
    @State private var draftKubeContext: String = ""
    @State private var draftTargetName: String = ""
    @State private var draftKubeTargetType: KubeTargetType = .pod
    @State private var draftUsePattern: Bool = true


    @State private var draftDockerYamlConfig: String = ""
    @State private var draftDockerInitialScript: String = ""
    @State private var draftPodmanYamlConfig: String = ""
    @State private var draftPodmanInitialScript: String = ""

    @State private var draftShellRunCommand: String = ""
    @State private var draftShellWorkingDirectory: String = ""

    @State private var draftSSHHost: String = ""
    @State private var draftSSHUser: String = ""
    @State private var draftSSHPort: String = "22"

    @State private var draftHttpCheckUrl: String = ""
    @State private var draftHttpCheckInterval: HealthCheckIntervalOption = .fast

    @State private var draftTunnelType: TunnelEngineOption = .cloudflare
    @State private var draftTunnelTargetUrl: String = "http://localhost:3000"
    @State private var draftNgrokAuthToken: String = ""

    @State private var draftMonitorProcessName: String = ""
    @State private var draftMonitorInterval: HealthCheckIntervalOption = .fast

    @State private var draftPorts: [KumaPortMappingItem] = []

    @State private var isEditScene: Bool = false
    @State private var isSaving: Bool = false
    @State private var initialPorts: [KumaPortMappingItem] = []

    private let serviceRepository: any ServiceRepositoryProtocol

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        viewModel: ServicesDeckViewModel,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        self.viewModel = viewModel
        self.serviceRepository = serviceRepository
    }

    private var snapshot: ServiceCardSnapshot? {
        viewModel.snapshots.first(where: { $0.id == serviceID })
    }

    private var runtime: ServiceRuntimeState {
        viewModel.runtimeStates[serviceID] ?? ServiceRuntimeState()
    }

    private var activeProvider: Provider? {
        if let activeProviderID {
            return providers.first(where: { $0.id == activeProviderID })
        }
        return providers.first
    }

    private var activeCategory: ProviderCategory {
        activeProvider?.type ?? snapshot?.providerCategory ?? .docker
    }

    private var hasPendingChanges: Bool {
        guard let srv = service else { return false }

        if draftName.trimmingCharacters(in: .whitespacesAndNewlines) != srv.name { return true }
        if draftDescription.trimmingCharacters(in: .whitespacesAndNewlines) != (srv.description ?? "") { return true }

        if let p = activeProvider {
            if draftProviderLabel.trimmingCharacters(in: .whitespacesAndNewlines) != (p.label ?? "") { return true }

            switch p.type {
            case .kubernetes:
                if draftKubeNamespace != (p.kubeNamespace ?? "") { return true }
                if draftKubeContext != (p.kubeContext ?? "") { return true }
                if draftTargetName != (p.targetName ?? "") { return true }
                if draftKubeTargetType.rawValue != (p.kubeTargetType ?? KubeTargetType.pod.rawValue) { return true }
                if draftUsePattern != (p.usePattern ?? true) { return true }
            case .docker:
                if draftDockerYamlConfig != (p.yamlConfig ?? "") { return true }
                if draftDockerInitialScript != (p.initialScript ?? "") { return true }
            case .podman:
                if draftPodmanYamlConfig != (p.yamlConfig ?? "") { return true }
                if draftPodmanInitialScript != (p.initialScript ?? "") { return true }
            case .shell:
                if draftShellRunCommand != (p.runCommand ?? "") { return true }
                if draftShellWorkingDirectory != (p.workingDirectory ?? "") { return true }
            case .ssh:
                if draftSSHHost != (p.sshHost ?? "") { return true }
                if draftSSHUser != (p.sshUser ?? "") { return true }
                let portStr = p.sshPort != nil ? "\(p.sshPort!)" : "22"
                if draftSSHPort != portStr { return true }
            case .httpCheck:
                if draftHttpCheckUrl != (p.httpCheckUrl ?? "") { return true }
                if draftHttpCheckInterval.rawValue != (p.httpCheckInterval ?? 5) { return true }
            case .tunnel:
                if draftTunnelType.rawValue != (p.tunnelType ?? "cloudflare") { return true }
                if draftTunnelTargetUrl != (p.tunnelTargetUrl ?? "http://localhost:3000") { return true }
                if draftNgrokAuthToken != (p.ngrokAuthToken ?? "") { return true }
            case .processMonitor:
                if draftMonitorProcessName != (p.monitorProcessName ?? "") { return true }
                if draftMonitorInterval.rawValue != (p.monitorInterval ?? 5) { return true }
            }
        }

        if draftPorts != initialPorts { return true }

        return false
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let snapshot {
                // Zone 1: Status Header (Fixed Top)
                InspectorStatusHeader(
                    snapshot: snapshot,
                    runtime: runtime,
                    isEditMode: isEditScene,
                    hasChanges: hasPendingChanges,
                    isSaving: isSaving,
                    onToggle: { viewModel.toggleService(id: serviceID) },
                    onToggleStar: { viewModel.toggleStarred(id: serviceID, workspaceID: workspaceID) },
                    onBackToOverview: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            isEditScene = false
                        }
                    },
                    onSave: { saveChanges() },
                    onCancel: { cancelChanges() }
                )

                Divider()
                    .padding(.horizontal, KumaSpacing.lg)

                if !isEditScene {
                    // MARK: - Scene 1: Overview (Direct General Form + Providers + Logs + Options)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // 1. General Identification Form (Direct Form)
                            KumaFormSection(
                                icon: "info.circle",
                                title: "General",
                                subtitle: "Service name and purpose"
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    KumaTextField(
                                        label: "Service Name",
                                        value: $draftName,
                                        placeholder: "Postgres DB"
                                    )

                                    KumaTextArea(
                                        label: "Description (Optional)",
                                        value: $draftDescription,
                                        placeholder: "Service purpose or notes...",
                                        minHeight: 52
                                    )
                                }
                            }

                            // 2. Providers Section
                            ServiceProvidersSectionView(
                                serviceID: serviceID,
                                providers: providers,
                                activeProviderID: $activeProviderID,
                                isEditing: true,
                                isRunning: runtime.status.isOperational,
                                onSelectProvider: { newID in
                                    switchProvider(to: newID)
                                },
                                onEditProviderDetails: { provider in
                                    activeProviderID = provider.id
                                    populateActiveProviderFields(for: provider.id)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                        isEditScene = true
                                    }
                                },
                                onSaveProvider: { provider in
                                    saveProviderDirectly(provider)
                                },
                                onDeleteProvider: { provider in
                                    deleteProvider(provider)
                                }
                            )

                            // 3. Mini Live Logs Section
                            InspectorMiniLogs(
                                serviceID: serviceID,
                                isRunning: runtime.status.isOperational
                            )

                            // 4. Options Section (Disable, Delete)
                            InspectorOptionsSection(
                                isDisabled: Binding(
                                    get: { draftIsDisabled },
                                    set: { newValue in
                                        draftIsDisabled = newValue
                                        toggleDisableDirectly(newValue)
                                    }
                                ),
                                isEditing: true,
                                onDelete: {
                                    showDeleteConfirmation = true
                                }
                            )



                        }
                        .padding(KumaSpacing.lg)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                } else {
                    // MARK: - Scene 2: Edit Configuration (Active Provider Sub-Form & Ports)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            InspectorFormSections(
                                providerCategory: activeCategory,
                                isEditing: true,
                                providerLabel: $draftProviderLabel,
                                kubeConfigVM: kubeConfigVM,
                                kubeNamespace: $draftKubeNamespace,
                                kubeContext: $draftKubeContext,
                                targetName: $draftTargetName,
                                kubeTargetType: $draftKubeTargetType,
                                usePattern: $draftUsePattern,
                                dockerYamlConfig: $draftDockerYamlConfig,
                                dockerInitialScript: $draftDockerInitialScript,
                                podmanYamlConfig: $draftPodmanYamlConfig,
                                podmanInitialScript: $draftPodmanInitialScript,
                                shellRunCommand: $draftShellRunCommand,
                                shellWorkingDirectory: $draftShellWorkingDirectory,
                                sshHost: $draftSSHHost,
                                sshUser: $draftSSHUser,
                                sshPort: $draftSSHPort,
                                httpCheckUrl: $draftHttpCheckUrl,
                                httpCheckInterval: $draftHttpCheckInterval,
                                tunnelType: $draftTunnelType,
                                tunnelTargetUrl: $draftTunnelTargetUrl,
                                ngrokAuthToken: $draftNgrokAuthToken,
                                monitorProcessName: $draftMonitorProcessName,
                                monitorInterval: $draftMonitorInterval,
                                ports: $draftPorts
                            )

                            // Provider Options Section (Delete Provider when providers > 1)
                            if providers.count > 1 {
                                KumaFormSection(
                                    icon: "gearshape.fill",
                                    title: "Options"
                                ) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Delete Provider")
                                                .font(KumaFont.body)
                                                .foregroundStyle(.red)
                                            Text("Permanently remove this provider.")
                                                .font(KumaFont.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button("Delete") {
                                            showDeleteProviderConfirmation = true
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                        .controlSize(.small)
                                    }
                                }
                            }


                        }
                        .padding(KumaSpacing.lg)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
                }
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service to view configuration details and live logs."
                )
            }
        }
        .task(id: serviceID) {
            await loadServiceDetails()
        }
        .onChange(of: activeProviderID) { _, newActiveID in
            populateActiveProviderFields(for: newActiveID)
        }
        .confirmationDialog(
            "Delete Service?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Service", role: .destructive) {
                Task {
                    try? await serviceRepository.deleteService(id: serviceID)
                    viewModel.loadWorkspace(workspaceID: workspaceID)
                    viewModel.selectedServiceID = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. '\(draftName)' and all associated runner configurations will be permanently deleted.")
        }
        .confirmationDialog(
            "Delete Provider?",
            isPresented: $showDeleteProviderConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Provider", role: .destructive) {
                if let p = activeProvider {
                    deleteProvider(p)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        isEditScene = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let label = activeProvider?.displayName ?? "this provider"
            Text("Are you sure you want to delete '\(label)'? Other configured providers will remain available.")
        }


    }

    // MARK: - Data Loading & State Synchronization

    private func loadServiceDetails() async {
        isLoadingData = true
        do {
            async let fetchService = serviceRepository.fetchService(id: serviceID)
            async let fetchProviders = serviceRepository.fetchProviders(forService: serviceID)
            async let fetchPorts = serviceRepository.fetchPortMappings(forService: serviceID)

            let (srv, provs, portList) = try await (fetchService, fetchProviders, fetchPorts)

            guard let srv else {
                isLoadingData = false
                return
            }

            self.service = srv
            self.providers = provs
            self.activeProviderID = srv.activeProviderID ?? provs.first?.id

            self.draftName = srv.name
            self.draftDescription = srv.description ?? ""
            self.draftIsDisabled = srv.isDisabled

            self.draftPorts = portList.map {
                KumaPortMappingItem(id: $0.id, local: "\($0.localPort)", remote: "\($0.remotePort)")
            }
            self.initialPorts = self.draftPorts

            populateActiveProviderFields(for: self.activeProviderID)
            self.isLoadingData = false
        } catch {
            self.isLoadingData = false
        }
    }

    private func cancelChanges() {
        guard let srv = service else { return }
        draftName = srv.name
        draftDescription = srv.description ?? ""
        draftIsDisabled = srv.isDisabled
        draftPorts = initialPorts
        populateActiveProviderFields(for: activeProviderID)
    }

    private func toggleDisableDirectly(_ disabled: Bool) {
        guard var srv = service else { return }
        srv.isDisabled = disabled
        srv.updatedAt = Date()
        self.service = srv
        Task {
            try? await serviceRepository.updateService(srv)
            viewModel.loadWorkspace(workspaceID: workspaceID)
        }
    }

    private func switchProvider(to providerID: UUID) {
        activeProviderID = providerID
        guard var srv = service else { return }
        srv.activeProviderID = providerID
        srv.updatedAt = Date()
        self.service = srv
        populateActiveProviderFields(for: providerID)
        Task {
            try? await serviceRepository.updateService(srv)
            viewModel.loadWorkspace(workspaceID: workspaceID)
        }
    }

    private func saveProviderDirectly(_ provider: Provider) {
        Task {
            if providers.contains(where: { $0.id == provider.id }) {
                try? await serviceRepository.updateProvider(provider)
            } else {
                try? await serviceRepository.insertProvider(provider)
            }
            await loadServiceDetails()
            viewModel.loadWorkspace(workspaceID: workspaceID)
        }
    }

    private func loadDraftFromDatabase() {
        Task {
            await loadServiceDetails()
        }
    }

    private func populateActiveProviderFields(for providerID: UUID?) {
        guard let p = providers.first(where: { $0.id == providerID }) ?? providers.first else { return }

        draftProviderLabel = p.label ?? ""
        if p.type == .kubernetes && kubeConfigVM == nil {
            kubeConfigVM = KubeConfigViewModel()
        }


        draftKubeNamespace = p.kubeNamespace ?? ""
        draftKubeContext = p.kubeContext ?? ""
        draftTargetName = p.targetName ?? ""
        draftKubeTargetType = KubeTargetType(rawValue: p.kubeTargetType ?? "") ?? .pod
        draftUsePattern = p.usePattern ?? true

        draftDockerYamlConfig = p.yamlConfig ?? ""
        draftDockerInitialScript = p.initialScript ?? ""

        draftPodmanYamlConfig = p.yamlConfig ?? ""
        draftPodmanInitialScript = p.initialScript ?? ""

        draftShellRunCommand = p.runCommand ?? ""
        draftShellWorkingDirectory = p.workingDirectory ?? ""

        draftSSHHost = p.sshHost ?? ""
        draftSSHUser = p.sshUser ?? ""
        draftSSHPort = p.sshPort != nil ? "\(p.sshPort!)" : "22"

        draftHttpCheckUrl = p.httpCheckUrl ?? ""
        draftHttpCheckInterval = HealthCheckIntervalOption(rawValue: p.httpCheckInterval ?? 5) ?? .fast

        draftTunnelType = TunnelEngineOption(rawValue: p.tunnelType ?? "cloudflare") ?? .cloudflare
        draftTunnelTargetUrl = p.tunnelTargetUrl ?? "http://localhost:3000"
        draftNgrokAuthToken = p.ngrokAuthToken ?? ""

        draftMonitorProcessName = p.monitorProcessName ?? ""
        draftMonitorInterval = HealthCheckIntervalOption(rawValue: p.monitorInterval ?? 5) ?? .fast
    }

    // MARK: - Save Actions

    private func saveChanges() {



        guard var srv = service else { return }
        isSaving = true

        srv.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        srv.description = draftDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        srv.isDisabled = draftIsDisabled
        srv.activeProviderID = activeProviderID
        srv.updatedAt = Date()

        var updatedProvider = activeProvider ?? Provider(serviceID: serviceID, type: .docker)
        updatedProvider.label = draftProviderLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draftProviderLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProvider.updatedAt = Date()


        switch updatedProvider.type {
        case .kubernetes:
            updatedProvider.kubeNamespace = draftKubeNamespace.isEmpty ? nil : draftKubeNamespace
            updatedProvider.kubeContext = draftKubeContext.isEmpty ? nil : draftKubeContext
            updatedProvider.targetName = draftTargetName.isEmpty ? nil : draftTargetName
            updatedProvider.kubeTargetType = draftKubeTargetType.rawValue
            updatedProvider.usePattern = draftUsePattern
        case .docker:
            updatedProvider.yamlConfig = draftDockerYamlConfig
            updatedProvider.initialScript = draftDockerInitialScript.isEmpty ? nil : draftDockerInitialScript
        case .podman:
            updatedProvider.yamlConfig = draftPodmanYamlConfig
            updatedProvider.initialScript = draftPodmanInitialScript.isEmpty ? nil : draftPodmanInitialScript
        case .shell:
            updatedProvider.runCommand = draftShellRunCommand
            updatedProvider.workingDirectory = draftShellWorkingDirectory.isEmpty ? nil : draftShellWorkingDirectory
        case .ssh:
            updatedProvider.sshHost = draftSSHHost.isEmpty ? nil : draftSSHHost
            updatedProvider.sshUser = draftSSHUser.isEmpty ? nil : draftSSHUser
            updatedProvider.sshPort = Int(draftSSHPort) ?? 22
        case .httpCheck:
            updatedProvider.httpCheckUrl = draftHttpCheckUrl
            updatedProvider.httpCheckInterval = draftHttpCheckInterval.rawValue
        case .tunnel:
            updatedProvider.tunnelType = draftTunnelType.rawValue
            updatedProvider.tunnelTargetUrl = draftTunnelTargetUrl
            updatedProvider.ngrokAuthToken = draftNgrokAuthToken.isEmpty ? nil : draftNgrokAuthToken
        case .processMonitor:
            updatedProvider.monitorProcessName = draftMonitorProcessName
            updatedProvider.monitorInterval = draftMonitorInterval.rawValue
        }

        let realPorts = draftPorts.compactMap { item -> ServicePortMapping? in
            guard let local = Int(item.local), let remote = Int(item.remote), local > 0, remote > 0 else { return nil }
            return ServicePortMapping(id: item.id, serviceID: serviceID, localPort: local, remotePort: remote, protocolType: "TCP")
        }

        Task {
            try? await serviceRepository.updateService(srv)
            try? await serviceRepository.updateProvider(updatedProvider)
            try? await serviceRepository.savePortMappings(realPorts, forService: serviceID)

            await MainActor.run {
                self.service = srv
                self.initialPorts = self.draftPorts
                self.isSaving = false
                viewModel.loadWorkspace(workspaceID: workspaceID)
            }
        }
    }

    // MARK: - Provider CRUD Helpers

    private func deleteProvider(_ provider: Provider) {
        Task {
            try? await serviceRepository.deleteProvider(id: provider.id)
            await loadServiceDetails()
            viewModel.loadWorkspace(workspaceID: workspaceID)
        }
    }
}

