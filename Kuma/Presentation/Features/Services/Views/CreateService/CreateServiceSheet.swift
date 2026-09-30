import SwiftUI
import os

public struct CreateServiceSheet: View {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "CreateServiceSheet")

    public let workspaceID: UUID
    public var onServiceCreated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    public enum CreationStep {
        case selectProvider
        case fillDetails
    }

    @State private var currentStep: CreationStep = .selectProvider
    @State private var selectedProvider: ProviderCategory = .kubernetes

    // Grouped Form Drafts
    @State private var generalDraft = ServiceGeneralDraft()
    @State private var kubeDraft = ServiceKubernetesDraft()
    @State private var kubeConfigVM = KubeConfigViewModel()
    @State private var dockerDraft = ServiceComposeDraft()
    @State private var podmanDraft = ServiceComposeDraft()
    @State private var shellDraft = ServiceShellDraft()
    @State private var sshDraft = ServiceSSHDraft()
    @State private var sshAuthType: SSHAuthType = .key
    @State private var sshKeyPath: String = "~/.ssh/id_ed25519"
    @State private var sshPassword: String = ""
    @State private var healthCheckDraft = ServiceHealthCheckDraft()
    @State private var tunnelDraft = ServiceTunnelDraft()
    @State private var monitorDraft = ServiceProcessMonitorDraft()

    // Dynamic Port Mappings & UI State
    @State private var temporaryPorts: [KumaPortMappingItem] = [KumaPortMappingItem()]
    @State private var isSaving: Bool = false

    public init(workspaceID: UUID, onServiceCreated: (() -> Void)? = nil) {
        self.workspaceID = workspaceID
        self.onServiceCreated = onServiceCreated
    }

    private var isFormValid: Bool {
        guard !generalDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

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
            return !kubeDraft.targetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .docker:
            return !dockerDraft.yamlConfig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .podman:
            return !podmanDraft.yamlConfig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .shell:
            return !shellDraft.runCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .ssh:
            return !sshDraft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !sshDraft.user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .httpCheck:
            return !healthCheckDraft.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tunnel:
            return !tunnelDraft.targetUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .processMonitor:
            return !monitorDraft.processName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                CreateServiceFillDetailsStepView(
                    selectedProvider: selectedProvider,
                    generalDraft: $generalDraft,
                    kubeDraft: $kubeDraft,
                    kubeConfigVM: kubeConfigVM,
                    dockerDraft: $dockerDraft,
                    podmanDraft: $podmanDraft,
                    shellDraft: $shellDraft,
                    sshDraft: $sshDraft,
                    sshAuthType: $sshAuthType,
                    sshKeyPath: $sshKeyPath,
                    sshPassword: $sshPassword,
                    healthCheckDraft: $healthCheckDraft,
                    tunnelDraft: $tunnelDraft,
                    monitorDraft: $monitorDraft,
                    temporaryPorts: $temporaryPorts,
                    isFormValid: isFormValid,
                    isSaving: isSaving,
                    onBack: { withAnimation { currentStep = .selectProvider } },
                    onCancel: { dismiss() },
                    onCreate: { createService() }
                )
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

    // MARK: - Save Action

    private func createService() {
        guard isFormValid, !isSaving else { return }
        isSaving = true

        let serviceID = UUID()
        let providerID = UUID()

        let service = Service(
            id: serviceID,
            name: generalDraft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: generalDraft.description.isEmpty ? nil : generalDraft.description.trimmingCharacters(in: .whitespacesAndNewlines),
            activeProviderID: providerID,
            workspaceID: workspaceID,
            isDisabled: generalDraft.isDisabled,
            isStarred: false
        )

        Task {
            do {
                var encryptedYaml: String? = nil
                var encryptedScript: String? = nil
                var encryptedPassword: String? = nil
                var encryptedKeyPath: String? = nil

                if selectedProvider == .docker {
                    let trimmedYaml = dockerDraft.yamlConfig.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedYaml.isEmpty { encryptedYaml = try await CryptoVault.shared.encrypt(plainText: trimmedYaml) }
                    let trimmedScript = dockerDraft.initialScript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedScript.isEmpty { encryptedScript = try await CryptoVault.shared.encrypt(plainText: trimmedScript) }
                } else if selectedProvider == .podman {
                    let trimmedYaml = podmanDraft.yamlConfig.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedYaml.isEmpty { encryptedYaml = try await CryptoVault.shared.encrypt(plainText: trimmedYaml) }
                    let trimmedScript = podmanDraft.initialScript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedScript.isEmpty { encryptedScript = try await CryptoVault.shared.encrypt(plainText: trimmedScript) }
                } else if selectedProvider == .ssh {
                    let trimmedPass = sshPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedPass.isEmpty { encryptedPassword = try await CryptoVault.shared.encrypt(plainText: trimmedPass) }
                    let trimmedKey = sshKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedKey.isEmpty { encryptedKeyPath = try await CryptoVault.shared.encrypt(plainText: trimmedKey) }
                } else if selectedProvider == .tunnel {
                    let trimmedToken = tunnelDraft.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedToken.isEmpty { encryptedPassword = try await CryptoVault.shared.encrypt(plainText: trimmedToken) }
                }

                let provider = Provider(
                    id: providerID,
                    serviceID: serviceID,
                    type: selectedProvider,
                    label: selectedProvider.sidebarLabel,
                    kubeConfigID: selectedProvider == .kubernetes ? kubeConfigVM.selectedKubeConfigID : nil,
                    kubeContext: kubeDraft.context.isEmpty ? nil : kubeDraft.context.trimmingCharacters(in: .whitespacesAndNewlines),
                    kubeNamespace: kubeDraft.namespace.isEmpty ? nil : kubeDraft.namespace.trimmingCharacters(in: .whitespacesAndNewlines),
                    targetName: kubeDraft.targetName.isEmpty ? nil : kubeDraft.targetName.trimmingCharacters(in: .whitespacesAndNewlines),
                    kubeTargetType: kubeDraft.targetType.rawValue,
                    usePattern: kubeDraft.usePattern,
                    yamlConfig: encryptedYaml,
                    initialScript: encryptedScript,
                    runCommand: selectedProvider == .shell && !shellDraft.runCommand.isEmpty ? shellDraft.runCommand.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    workingDirectory: selectedProvider == .shell && !shellDraft.workingDirectory.isEmpty ? shellDraft.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    sshHost: selectedProvider == .ssh && !sshDraft.host.isEmpty ? sshDraft.host.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    sshUser: selectedProvider == .ssh && !sshDraft.user.isEmpty ? sshDraft.user.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    sshPort: selectedProvider == .ssh ? Int(sshDraft.port.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 22 : nil,
                    sshKeyPath: selectedProvider == .ssh && sshAuthType == .key ? encryptedKeyPath : nil,
                    sshPassword: selectedProvider == .ssh && sshAuthType == .password ? encryptedPassword : nil,
                    httpCheckUrl: selectedProvider == .httpCheck && !healthCheckDraft.url.isEmpty ? healthCheckDraft.url.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    httpCheckInterval: selectedProvider == .httpCheck ? healthCheckDraft.interval.rawValue : nil,
                    tunnelType: selectedProvider == .tunnel ? tunnelDraft.engine.rawValue : nil,
                    tunnelTargetUrl: selectedProvider == .tunnel && !tunnelDraft.targetUrl.isEmpty ? tunnelDraft.targetUrl.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    ngrokAuthToken: selectedProvider == .tunnel && tunnelDraft.engine == .ngrok ? encryptedPassword : nil,
                    monitorProcessName: selectedProvider == .processMonitor && !monitorDraft.processName.isEmpty ? monitorDraft.processName.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    monitorInterval: selectedProvider == .processMonitor ? monitorDraft.interval.rawValue : nil
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
                Self.logger.error("Failed to create service: \(error.localizedDescription)")
                isSaving = false
            }
        }
    }
}
