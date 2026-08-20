import SwiftUI

public struct CreateServiceSheet: View {
    public let workspaceID: UUID
    public var onServiceCreated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    public enum CreationStep {
        case selectProvider
        case fillDetails
    }

    @State private var currentStep: CreationStep = .selectProvider
    @State private var selectedProvider: ProviderCategory = .kubernetes

    // General Information
    @State private var name: String = ""
    @State private var serviceDescription: String = ""
    @State private var isDisabled: Bool = false

    // Kubernetes Provider Settings
    @State private var kubeConfigVM = KubeConfigViewModel()
    @State private var kubeContext: String = ""
    @State private var kubeNamespace: String = ""
    @State private var targetName: String = ""
    @State private var kubeTargetType: KubeTargetType = .pod
    @State private var usePattern: Bool = true

    // Docker Provider Settings
    @State private var dockerYamlConfig: String = ""
    @State private var dockerInitialScript: String = ""

    // Podman Provider Settings
    @State private var podmanYamlConfig: String = ""
    @State private var podmanInitialScript: String = ""

    // Shell Execution Provider Settings
    @State private var shellRunCommand: String = ""
    @State private var shellWorkingDirectory: String = ""

    // SSH Remote Provider Settings
    @State private var sshHost: String = ""
    @State private var sshPort: String = "22"
    @State private var sshUser: String = ""
    @State private var sshAuthType: SSHAuthType = .key
    @State private var sshKeyPath: String = "~/.ssh/id_ed25519"

    @State private var sshPassword: String = ""

    // Health Check Provider Settings
    @State private var httpCheckUrl: String = ""
    @State private var httpCheckInterval: HealthCheckIntervalOption = .fast

    // Public Tunnel Provider Settings
    @State private var tunnelType: TunnelEngineOption = .cloudflare
    @State private var tunnelTargetUrl: String = "http://localhost:3000"
    @State private var ngrokAuthToken: String = ""

    // Process Monitor Provider Settings
    @State private var monitorProcessName: String = ""
    @State private var monitorInterval: HealthCheckIntervalOption = .fast

    // Dynamic Port Mappings
    @State private var temporaryPorts: [KumaPortMappingItem] = [KumaPortMappingItem()]
    @State private var isSaving: Bool = false

    public init(workspaceID: UUID, onServiceCreated: (() -> Void)? = nil) {
        self.workspaceID = workspaceID
        self.onServiceCreated = onServiceCreated
    }

    private var isFormValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        if selectedProvider == .kubernetes || selectedProvider == .ssh {
            for port in temporaryPorts {
                let local = port.local.trimmingCharacters(in: .whitespacesAndNewlines)
                let remote = port.remote.trimmingCharacters(in: .whitespacesAndNewlines)
                if !local.isEmpty || !remote.isEmpty {
                    guard let lVal = Int(local), let rVal = Int(remote),
                          lVal > 0, lVal <= 65535,
                          rVal > 0, rVal <= 65535 else {
                        return false
                    }
                }
            }
        }

        switch selectedProvider {
        case .kubernetes:
            return !targetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .docker:
            return !dockerYamlConfig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .podman:
            return !podmanYamlConfig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .shell:
            return !shellRunCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .ssh:
            return !sshHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !sshUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .httpCheck:
            return !httpCheckUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tunnel:
            return !tunnelTargetUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .processMonitor:
            return !monitorProcessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var serviceNamePlaceholder: String {
        switch selectedProvider {
        case .kubernetes: return "PostgreSQL Database"
        case .docker, .podman: return "Redis Cache"
        case .shell: return "Frontend Dev Server"
        case .ssh: return "Staging Bastion Tunnel"
        case .httpCheck: return "Auth Service Health"
        case .tunnel: return "Webhook Public Tunnel"
        case .processMonitor: return "Redis Server Monitor"
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            switch currentStep {
            case .selectProvider:
                CreateServiceProviderStepView(
                    selectedProvider: $selectedProvider,
                    onContinue: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            currentStep = .fillDetails
                        }
                    },
                    onCancel: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            case .fillDetails:
                fillDetailsStepView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentStep)
        .frame(
            width: currentStep == .selectProvider ? 520 : 500,
            height: currentStep == .selectProvider ? 440 : 580
        )
    }



    // MARK: - Fill Details Step View

    private var fillDetailsStepView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Bar with Back Button
                    HStack(spacing: 10) {
                        Button {
                            withAnimation { currentStep = .selectProvider }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to Provider selection")

                        Text("Service Details (\(selectedProvider.sidebarLabel))")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.top, 16)

                    // 1. General Section
                    ServiceGeneralSettingsView(
                        name: $name,
                        serviceDescription: $serviceDescription,
                        placeholder: serviceNamePlaceholder
                    )

                    // 2. Contextual Provider Settings
                    providerSpecificSection

                    // 3. Port Mappings Section (Shown for Kubernetes and SSH)
                    if selectedProvider == .kubernetes || selectedProvider == .ssh {
                        KumaFormSection(
                            icon: "arrow.left.arrow.right",
                            title: "Ports"
                        ) {
                            KumaPortMappingEditor(label: "", items: $temporaryPorts)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            Divider().opacity(0.4)

            // Bottom Action Bar
            HStack {
                Button("Back") {
                    withAnimation { currentStep = .selectProvider }
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .padding(.trailing, 8)

                Button("Create") {
                    createService()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid || isSaving)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }


    // MARK: - Provider Specific Subview

    @ViewBuilder
    private var providerSpecificSection: some View {
        switch selectedProvider {
        case .kubernetes:
            KubeConfigConnectionView(
                viewModel: kubeConfigVM,
                isLocked: false,
                contextToTest: kubeContext,
                onConfigChanged: {}
            )

            KumaFormSection(icon: "network", title: "Cluster Connection") {
                KubeConnectionSettingsView(
                    kubeNamespace: $kubeNamespace,
                    kubeContext: $kubeContext,
                    availableContexts: kubeConfigVM.availableContexts
                )
            }
            .onChange(of: kubeConfigVM.availableContexts, initial: true) { _, contexts in
                if let active = kubeConfigVM.activeContextName, contexts.contains(active) {
                    kubeContext = active
                } else if let first = contexts.first, !contexts.contains(kubeContext) {
                    kubeContext = first
                }
            }


            KumaFormSection(icon: "scope", title: "Target Resource") {
                KubeTargetSettingsView(
                    targetName: $targetName,
                    targetType: $kubeTargetType,
                    usePattern: $usePattern
                )
            }

        case .docker:
            KumaFormSection(icon: "shippingbox.fill", title: "Docker Compose") {
                DockerComposeSettingsView(yamlConfig: $dockerYamlConfig)
            }
            KumaFormSection(icon: "terminal.fill", title: "Initial Script") {
                InitialScriptSettingsView(initialScript: $dockerInitialScript)
            }

        case .podman:
            KumaFormSection(icon: "shippingbox.fill", title: "Podman Compose") {
                PodmanComposeSettingsView(yamlConfig: $podmanYamlConfig)
            }
            KumaFormSection(icon: "terminal.fill", title: "Initial Script") {
                InitialScriptSettingsView(initialScript: $podmanInitialScript)
            }



        case .shell:
            KumaFormSection(icon: "terminal.fill", title: "Shell Command") {
                ShellScriptSettingsView(runCommand: $shellRunCommand, workingDirectory: $shellWorkingDirectory)
            }

        case .ssh:
            KumaFormSection(icon: "network", title: "SSH Connection") {
                SSHSettingsView(
                    sshHost: $sshHost,
                    sshPort: $sshPort,
                    sshUser: $sshUser,
                    authType: $sshAuthType,
                    sshKeyPath: $sshKeyPath,
                    sshPassword: $sshPassword
                )
            }

        case .httpCheck:
            KumaFormSection(icon: "heart.text.square.fill", title: "Health Check") {
                HealthCheckSettingsView(httpCheckUrl: $httpCheckUrl, checkInterval: $httpCheckInterval)
            }

        case .tunnel:
            KumaFormSection(icon: "cloud.bolt.fill", title: "Public Tunnel") {
                TunnelSettingsView(tunnelType: $tunnelType, tunnelTargetUrl: $tunnelTargetUrl, ngrokAuthToken: $ngrokAuthToken)
            }

        case .processMonitor:
            KumaFormSection(icon: "cpu.fill", title: "Process Monitor") {
                ProcessMonitorSettingsView(monitorProcessName: $monitorProcessName, monitorInterval: $monitorInterval)
            }
        }
    }

    // MARK: - Save Action

    private func createService() {
        guard isFormValid, !isSaving else { return }
        isSaving = true

        let serviceID = UUID()
        let providerID = UUID()

        let service = Service(
            id: serviceID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: serviceDescription.isEmpty ? nil : serviceDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            activeProviderID: providerID,
            workspaceID: workspaceID,
            isDisabled: isDisabled,
            isStarred: false
        )

        Task {
            do {
                var encryptedYaml: String? = nil
                var encryptedScript: String? = nil
                var encryptedPassword: String? = nil
                var encryptedKeyPath: String? = nil

                if selectedProvider == .docker {
                    let trimmedYaml = dockerYamlConfig.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedYaml.isEmpty { encryptedYaml = try await CryptoVault.shared.encrypt(plainText: trimmedYaml) }
                    let trimmedScript = dockerInitialScript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedScript.isEmpty { encryptedScript = try await CryptoVault.shared.encrypt(plainText: trimmedScript) }
                } else if selectedProvider == .podman {
                    let trimmedYaml = podmanYamlConfig.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedYaml.isEmpty { encryptedYaml = try await CryptoVault.shared.encrypt(plainText: trimmedYaml) }
                    let trimmedScript = podmanInitialScript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedScript.isEmpty { encryptedScript = try await CryptoVault.shared.encrypt(plainText: trimmedScript) }
                } else if selectedProvider == .ssh {
                    let trimmedPass = sshPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedPass.isEmpty { encryptedPassword = try await CryptoVault.shared.encrypt(plainText: trimmedPass) }
                    let trimmedKey = sshKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedKey.isEmpty { encryptedKeyPath = try await CryptoVault.shared.encrypt(plainText: trimmedKey) }
                } else if selectedProvider == .tunnel {
                    let trimmedToken = ngrokAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedToken.isEmpty { encryptedPassword = try await CryptoVault.shared.encrypt(plainText: trimmedToken) }
                }

                let provider = Provider(
                    id: providerID,
                    serviceID: serviceID,
                    type: selectedProvider,
                    label: selectedProvider.sidebarLabel,
                    kubeConfigID: selectedProvider == .kubernetes ? kubeConfigVM.selectedKubeConfigID : nil,
                    kubeContext: kubeContext.isEmpty ? nil : kubeContext.trimmingCharacters(in: .whitespacesAndNewlines),
                    kubeNamespace: kubeNamespace.isEmpty ? nil : kubeNamespace.trimmingCharacters(in: .whitespacesAndNewlines),
                    targetName: targetName.isEmpty ? nil : targetName.trimmingCharacters(in: .whitespacesAndNewlines),
                    kubeTargetType: kubeTargetType.rawValue,
                    usePattern: usePattern,
                    yamlConfig: encryptedYaml,
                    initialScript: encryptedScript,
                    runCommand: selectedProvider == .shell && !shellRunCommand.isEmpty ? shellRunCommand.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    workingDirectory: selectedProvider == .shell && !shellWorkingDirectory.isEmpty ? shellWorkingDirectory.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    sshHost: selectedProvider == .ssh && !sshHost.isEmpty ? sshHost.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    sshUser: selectedProvider == .ssh && !sshUser.isEmpty ? sshUser.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    sshPort: selectedProvider == .ssh ? Int(sshPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 22 : nil,
                    sshKeyPath: selectedProvider == .ssh && sshAuthType == .key ? encryptedKeyPath : nil,
                    sshPassword: selectedProvider == .ssh && sshAuthType == .password ? encryptedPassword : nil,
                    httpCheckUrl: selectedProvider == .httpCheck && !httpCheckUrl.isEmpty ? httpCheckUrl.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    httpCheckInterval: selectedProvider == .httpCheck ? httpCheckInterval.rawValue : nil,
                    tunnelType: selectedProvider == .tunnel ? tunnelType.rawValue : nil,
                    tunnelTargetUrl: selectedProvider == .tunnel && !tunnelTargetUrl.isEmpty ? tunnelTargetUrl.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    ngrokAuthToken: selectedProvider == .tunnel && tunnelType == .ngrok ? encryptedPassword : nil,
                    monitorProcessName: selectedProvider == .processMonitor && !monitorProcessName.isEmpty ? monitorProcessName.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    monitorInterval: selectedProvider == .processMonitor ? monitorInterval.rawValue : nil
                )

                let portMappings: [ServicePortMapping]
                if selectedProvider == .kubernetes || selectedProvider == .ssh {
                    portMappings = temporaryPorts.compactMap { item -> ServicePortMapping? in
                        guard let local = Int(item.local), let remote = Int(item.remote), local > 0, remote > 0 else { return nil }
                        return ServicePortMapping(
                            id: item.id,
                            serviceID: serviceID,
                            localPort: local,
                            remotePort: remote
                        )
                    }
                } else {
                    portMappings = []
                }

                let repo = ServiceRepository()
                try await repo.insertService(service, defaultProvider: provider, portMappings: portMappings)
                onServiceCreated?()
                dismiss()
            } catch {
                isSaving = false
            }
        }
    }
}
