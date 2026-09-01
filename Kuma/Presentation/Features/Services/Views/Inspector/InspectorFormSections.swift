import SwiftUI

public struct InspectorFormSections: View {
    @Binding public var provider: Provider
    @Binding public var ports: [KumaPortMappingItem]
    public var kubeConfigVM: KubeConfigViewModel?
    public let isLocked: Bool
    public let onFieldChanged: () -> Void

    public init(
        provider: Binding<Provider>,
        ports: Binding<[KumaPortMappingItem]>,
        kubeConfigVM: KubeConfigViewModel? = nil,
        isLocked: Bool = false,
        onFieldChanged: @escaping () -> Void = {}
    ) {
        self._provider = provider
        self._ports = ports
        self.kubeConfigVM = kubeConfigVM
        self.isLocked = isLocked
        self.onFieldChanged = onFieldChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch provider.type {

            case .kubernetes:
                if let kubeConfigVM {
                    KubeConfigConnectionView(
                        viewModel: kubeConfigVM,
                        isLocked: isLocked,
                        contextToTest: provider.kubeContext ?? "",
                        onConfigChanged: onFieldChanged
                    )
                    .disabled(isLocked)

                    KumaFormSection(icon: "network", title: "Cluster Connection") {
                        KubeConnectionSettingsView(
                            kubeNamespace: Binding(
                                get: { provider.kubeNamespace ?? "" },
                                set: { provider.kubeNamespace = $0.isEmpty ? nil : $0; onFieldChanged() }
                            ),
                            kubeContext: Binding(
                                get: { provider.kubeContext ?? "" },
                                set: { provider.kubeContext = $0.isEmpty ? nil : $0; onFieldChanged() }
                            ),
                            availableContexts: kubeConfigVM.availableContexts
                        )
                        .disabled(isLocked)
                    }
                }

                KumaFormSection(icon: "scope", title: "Target Resource") {
                    KubeTargetSettingsView(
                        targetName: Binding(
                            get: { provider.targetName ?? "" },
                            set: { provider.targetName = $0.isEmpty ? nil : $0; onFieldChanged() }
                        ),
                        targetType: Binding(
                            get: { KubeTargetType(rawValue: provider.kubeTargetType ?? "") ?? .pod },
                            set: { provider.kubeTargetType = $0.rawValue; onFieldChanged() }
                        ),
                        usePattern: Binding(
                            get: { provider.usePattern ?? true },
                            set: { provider.usePattern = $0; onFieldChanged() }
                        )
                    )
                    .disabled(isLocked)
                }

            case .docker:
                KumaFormSection(icon: "shippingbox.fill", title: "Configuration") {
                    VStack(alignment: .leading, spacing: 14) {
                        DockerComposeSettingsView(
                            yamlConfig: Binding(
                                get: { provider.yamlConfig ?? "" },
                                set: { provider.yamlConfig = $0; onFieldChanged() }
                            ),
                            onSave: onFieldChanged
                        )

                        KumaDivider(opacity: 0.06, verticalPadding: 2)

                        InitialScriptSettingsView(
                            initialScript: Binding(
                                get: { provider.initialScript ?? "" },
                                set: { provider.initialScript = $0.isEmpty ? nil : $0; onFieldChanged() }
                            ),
                            onSave: onFieldChanged
                        )
                    }
                    .disabled(isLocked)
                }

            case .podman:
                KumaFormSection(icon: "shippingbox.fill", title: "Configuration") {
                    VStack(alignment: .leading, spacing: 14) {
                        PodmanComposeSettingsView(
                            yamlConfig: Binding(
                                get: { provider.yamlConfig ?? "" },
                                set: { provider.yamlConfig = $0; onFieldChanged() }
                            ),
                            onSave: onFieldChanged
                        )

                        KumaDivider(opacity: 0.06, verticalPadding: 2)

                        InitialScriptSettingsView(
                            initialScript: Binding(
                                get: { provider.initialScript ?? "" },
                                set: { provider.initialScript = $0.isEmpty ? nil : $0; onFieldChanged() }
                            ),
                            onSave: onFieldChanged
                        )
                    }
                    .disabled(isLocked)
                }

            case .shell:
                KumaFormSection(icon: "terminal.fill", title: "Shell Command") {
                    ShellScriptSettingsView(
                        runCommand: Binding(
                            get: { provider.runCommand ?? "" },
                            set: { provider.runCommand = $0; onFieldChanged() }
                        ),
                        workingDirectory: Binding(
                            get: { provider.workingDirectory ?? "" },
                            set: { provider.workingDirectory = $0.isEmpty ? nil : $0; onFieldChanged() }
                        )
                    )
                    .disabled(isLocked)
                }

            case .ssh:
                KumaFormSection(icon: "network", title: "SSH Connection") {
                    SSHSettingsView(
                        sshHost: Binding(
                            get: { provider.sshHost ?? "" },
                            set: { provider.sshHost = $0.isEmpty ? nil : $0; onFieldChanged() }
                        ),
                        sshPort: Binding(
                            get: { provider.sshPort != nil ? "\(provider.sshPort!)" : "22" },
                            set: { provider.sshPort = Int($0) ?? 22; onFieldChanged() }
                        ),
                        sshUser: Binding(
                            get: { provider.sshUser ?? "" },
                            set: { provider.sshUser = $0.isEmpty ? nil : $0; onFieldChanged() }
                        ),
                        authType: Binding(
                            get: { (provider.sshPassword != nil && !provider.sshPassword!.isEmpty) ? .password : .key },
                            set: { _ in onFieldChanged() }
                        ),
                        sshKeyPath: Binding(
                            get: { provider.sshKeyPath ?? "~/.ssh/id_ed25519" },
                            set: { provider.sshKeyPath = $0; onFieldChanged() }
                        ),
                        sshPassword: Binding(
                            get: { provider.sshPassword ?? "" },
                            set: { provider.sshPassword = $0; onFieldChanged() }
                        )
                    )
                    .disabled(isLocked)
                }

            case .httpCheck:
                KumaFormSection(icon: "heart.text.square.fill", title: "Health Check") {
                    HealthCheckSettingsView(
                        httpCheckUrl: Binding(
                            get: { provider.httpCheckUrl ?? "" },
                            set: { provider.httpCheckUrl = $0; onFieldChanged() }
                        ),
                        checkInterval: Binding(
                            get: { HealthCheckIntervalOption(rawValue: provider.httpCheckInterval ?? 5) ?? .fast },
                            set: { provider.httpCheckInterval = $0.rawValue; onFieldChanged() }
                        )
                    )
                    .disabled(isLocked)
                }

            case .tunnel:
                KumaFormSection(icon: "cloud.bolt.fill", title: "Public Tunnel") {
                    TunnelSettingsView(
                        tunnelType: Binding(
                            get: { TunnelEngineOption(rawValue: provider.tunnelType ?? "cloudflare") ?? .cloudflare },
                            set: { provider.tunnelType = $0.rawValue; onFieldChanged() }
                        ),
                        tunnelTargetUrl: Binding(
                            get: { provider.tunnelTargetUrl ?? "http://localhost:3000" },
                            set: { provider.tunnelTargetUrl = $0; onFieldChanged() }
                        ),
                        ngrokAuthToken: Binding(
                            get: { provider.ngrokAuthToken ?? "" },
                            set: { provider.ngrokAuthToken = $0.isEmpty ? nil : $0; onFieldChanged() }
                        )
                    )
                    .disabled(isLocked)
                }

            case .processMonitor:
                KumaFormSection(icon: "cpu.fill", title: "Process Monitor") {
                    ProcessMonitorSettingsView(
                        monitorProcessName: Binding(
                            get: { provider.monitorProcessName ?? "" },
                            set: { provider.monitorProcessName = $0; onFieldChanged() }
                        ),
                        monitorInterval: Binding(
                            get: { HealthCheckIntervalOption(rawValue: provider.monitorInterval ?? 5) ?? .fast },
                            set: { provider.monitorInterval = $0.rawValue; onFieldChanged() }
                        )
                    )
                    .disabled(isLocked)
                }
            }

            // Ports Section (Shown for Kubernetes and SSH)
            if provider.type == .kubernetes || provider.type == .ssh {
                KumaFormSection(icon: "arrow.left.arrow.right", title: "Ports") {
                    KumaPortMappingEditor(label: "", items: $ports)
                        .disabled(isLocked)
                        .onChange(of: ports) { _, _ in
                            onFieldChanged()
                        }
                }
            }
        }
    }
}
