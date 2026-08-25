import SwiftUI

public struct InspectorFormSections: View {
    public let providerCategory: ProviderCategory
    public let isEditing: Bool

    // Grouped Form Draft Bindings
    public var kubeConfigVM: KubeConfigViewModel?
    @Binding public var kubeDraft: ServiceKubernetesDraft
    @Binding public var dockerDraft: ServiceComposeDraft
    @Binding public var podmanDraft: ServiceComposeDraft
    @Binding public var shellDraft: ServiceShellDraft
    @Binding public var sshDraft: ServiceSSHDraft
    @Binding public var healthCheckDraft: ServiceHealthCheckDraft
    @Binding public var tunnelDraft: ServiceTunnelDraft
    @Binding public var monitorDraft: ServiceProcessMonitorDraft
    @Binding public var ports: [KumaPortMappingItem]

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch providerCategory {

            case .kubernetes:
                if let kubeConfigVM {
                    KubeConfigConnectionView(
                        viewModel: kubeConfigVM,
                        isLocked: !isEditing,
                        contextToTest: kubeDraft.context,
                        onConfigChanged: {}
                    )
                    .disabled(!isEditing)

                    KumaFormSection(icon: "network", title: "Cluster Connection") {
                        KubeConnectionSettingsView(
                            kubeNamespace: $kubeDraft.namespace,
                            kubeContext: $kubeDraft.context,
                            availableContexts: kubeConfigVM.availableContexts
                        )
                        .disabled(!isEditing)
                    }
                    .onChange(of: kubeConfigVM.availableContexts, initial: true) { _, contexts in
                        if let active = kubeConfigVM.activeContextName, contexts.contains(active) {
                            kubeDraft.context = active
                        } else if let first = contexts.first, !contexts.contains(kubeDraft.context) {
                            kubeDraft.context = first
                        }
                    }
                }

                KumaFormSection(icon: "scope", title: "Target Resource") {
                    KubeTargetSettingsView(
                        targetName: $kubeDraft.targetName,
                        targetType: $kubeDraft.targetType,
                        usePattern: $kubeDraft.usePattern
                    )
                    .disabled(!isEditing)
                }

            case .docker:
                KumaFormSection(icon: "shippingbox.fill", title: "Docker Compose") {
                    DockerComposeSettingsView(yamlConfig: $dockerDraft.yamlConfig)
                        .disabled(!isEditing)
                }
                KumaFormSection(icon: "terminal.fill", title: "Initial Script") {
                    InitialScriptSettingsView(initialScript: $dockerDraft.initialScript)
                        .disabled(!isEditing)
                }

            case .podman:
                KumaFormSection(icon: "shippingbox.fill", title: "Podman Compose") {
                    PodmanComposeSettingsView(yamlConfig: $podmanDraft.yamlConfig)
                        .disabled(!isEditing)
                }
                KumaFormSection(icon: "terminal.fill", title: "Initial Script") {
                    InitialScriptSettingsView(initialScript: $podmanDraft.initialScript)
                        .disabled(!isEditing)
                }

            case .shell:
                KumaFormSection(icon: "terminal.fill", title: "Shell Command") {
                    ShellScriptSettingsView(runCommand: $shellDraft.runCommand, workingDirectory: $shellDraft.workingDirectory)
                        .disabled(!isEditing)
                }

            case .ssh:
                KumaFormSection(icon: "network", title: "SSH Connection") {
                    SSHSettingsView(
                        sshHost: $sshDraft.host,
                        sshPort: $sshDraft.port,
                        sshUser: $sshDraft.user,
                        authType: $sshDraft.authType,
                        sshKeyPath: $sshDraft.keyPath,
                        sshPassword: $sshDraft.password
                    )
                    .disabled(!isEditing)
                }

            case .httpCheck:
                KumaFormSection(icon: "heart.text.square.fill", title: "Health Check") {
                    HealthCheckSettingsView(
                        httpCheckUrl: $healthCheckDraft.url,
                        checkInterval: $healthCheckDraft.interval
                    )
                    .disabled(!isEditing)
                }

            case .tunnel:
                KumaFormSection(icon: "cloud.bolt.fill", title: "Public Tunnel") {
                    TunnelSettingsView(
                        tunnelType: $tunnelDraft.engine,
                        tunnelTargetUrl: $tunnelDraft.targetUrl,
                        ngrokAuthToken: $tunnelDraft.authToken
                    )
                    .disabled(!isEditing)
                }

            case .processMonitor:
                KumaFormSection(icon: "cpu.fill", title: "Process Monitor") {
                    ProcessMonitorSettingsView(
                        monitorProcessName: $monitorDraft.processName,
                        monitorInterval: $monitorDraft.interval
                    )
                    .disabled(!isEditing)
                }
            }

            // Ports Section (Shown for Kubernetes and SSH)
            if providerCategory == .kubernetes || providerCategory == .ssh {
                KumaFormSection(
                    icon: "arrow.left.arrow.right",
                    title: "Ports"
                ) {
                    KumaPortMappingEditor(
                        label: "",
                        items: $ports
                    )
                    .disabled(!isEditing)
                }
            }
        }
    }

    private var podmanInitialScript: Binding<String> {
        $podmanDraft.initialScript
    }
}
