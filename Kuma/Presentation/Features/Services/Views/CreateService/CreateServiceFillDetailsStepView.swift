import SwiftUI

public struct CreateServiceFillDetailsStepView: View {
    public let selectedProvider: ProviderCategory
    @Binding public var generalDraft: ServiceGeneralDraft
    @Binding public var kubeDraft: ServiceKubernetesDraft
    public var kubeConfigVM: KubeConfigViewModel
    @Binding public var dockerDraft: ServiceComposeDraft
    @Binding public var podmanDraft: ServiceComposeDraft
    @Binding public var shellDraft: ServiceShellDraft
    @Binding public var sshDraft: ServiceSSHDraft
    @Binding public var sshAuthType: SSHAuthType
    @Binding public var sshKeyPath: String
    @Binding public var sshPassword: String
    @Binding public var healthCheckDraft: ServiceHealthCheckDraft
    @Binding public var tunnelDraft: ServiceTunnelDraft
    @Binding public var monitorDraft: ServiceProcessMonitorDraft
    @Binding public var temporaryPorts: [KumaPortMappingItem]

    public var isFormValid: Bool
    public var isSaving: Bool
    public let onBack: () -> Void
    public let onCancel: () -> Void
    public let onCreate: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Bar with Back Button
                    HStack(spacing: 10) {
                        Button {
                            onBack()
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
                        name: $generalDraft.name,
                        serviceDescription: $generalDraft.description,
                        placeholder: placeholderName
                    )

                    // 2. Contextual Provider Settings
                    providerSettingsSection

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
                Button("Back") { onBack() }

                Spacer()

                Button("Cancel") { onCancel() }
                    .padding(.trailing, 8)

                Button("Create") { onCreate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid || isSaving)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var placeholderName: String {
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

    @ViewBuilder
    private var providerSettingsSection: some View {
        switch selectedProvider {
        case .kubernetes:
            KubeConfigConnectionView(
                viewModel: kubeConfigVM,
                isLocked: false,
                contextToTest: kubeDraft.context,
                onConfigChanged: {}
            )

            KumaFormSection(icon: "network", title: "Cluster Connection") {
                KubeConnectionSettingsView(
                    kubeNamespace: $kubeDraft.namespace,
                    kubeContext: $kubeDraft.context,
                    availableContexts: kubeConfigVM.availableContexts
                )
            }
            .onChange(of: kubeConfigVM.availableContexts, initial: true) { _, contexts in
                if let active = kubeConfigVM.activeContextName, contexts.contains(active) {
                    kubeDraft.context = active
                } else if let first = contexts.first, !contexts.contains(kubeDraft.context) {
                    kubeDraft.context = first
                }
            }

            KumaFormSection(icon: "scope", title: "Target Resource") {
                KubeTargetSettingsView(
                    targetName: $kubeDraft.targetName,
                    targetType: $kubeDraft.targetType,
                    usePattern: $kubeDraft.usePattern
                )
            }

        case .docker:
            KumaFormSection(icon: "shippingbox.fill", title: "Docker Compose") {
                DockerComposeSettingsView(yamlConfig: $dockerDraft.yamlConfig)
            }
            KumaFormSection(icon: "terminal.fill", title: "Initial Script") {
                InitialScriptSettingsView(initialScript: $dockerDraft.initialScript)
            }

        case .podman:
            KumaFormSection(icon: "shippingbox.fill", title: "Podman Compose") {
                PodmanComposeSettingsView(yamlConfig: $podmanDraft.yamlConfig)
            }
            KumaFormSection(icon: "terminal.fill", title: "Initial Script") {
                InitialScriptSettingsView(initialScript: $podmanDraft.initialScript)
            }

        case .shell:
            KumaFormSection(icon: "terminal.fill", title: "Shell Command") {
                ShellScriptSettingsView(runCommand: $shellDraft.runCommand, workingDirectory: $shellDraft.workingDirectory)
            }

        case .ssh:
            KumaFormSection(icon: "network", title: "SSH Connection") {
                SSHSettingsView(
                    sshHost: $sshDraft.host,
                    sshPort: $sshDraft.port,
                    sshUser: $sshDraft.user,
                    authType: $sshAuthType,
                    sshKeyPath: $sshKeyPath,
                    sshPassword: $sshPassword
                )
            }

        case .httpCheck:
            KumaFormSection(icon: "heart.text.square.fill", title: "Health Check") {
                HealthCheckSettingsView(httpCheckUrl: $healthCheckDraft.url, checkInterval: $healthCheckDraft.interval)
            }

        case .tunnel:
            KumaFormSection(icon: "cloud.bolt.fill", title: "Public Tunnel") {
                TunnelSettingsView(tunnelType: $tunnelDraft.engine, tunnelTargetUrl: $tunnelDraft.targetUrl, ngrokAuthToken: $tunnelDraft.authToken)
            }

        case .processMonitor:
            KumaFormSection(icon: "cpu.fill", title: "Process Monitor") {
                ProcessMonitorSettingsView(monitorProcessName: $monitorDraft.processName, monitorInterval: $monitorDraft.interval)
            }
        }
    }
}
