import SwiftUI

public struct InspectorFormSections: View {
    public let providerCategory: ProviderCategory
    public let isEditing: Bool

    // Provider Custom Label Binding
    @Binding public var providerLabel: String

    // Kubernetes Bindings
    public var kubeConfigVM: KubeConfigViewModel?
    @Binding public var kubeNamespace: String
    @Binding public var kubeContext: String

    @Binding public var targetName: String
    @Binding public var kubeTargetType: KubeTargetType
    @Binding public var usePattern: Bool

    // Docker & Podman Bindings
    @Binding public var dockerYamlConfig: String
    @Binding public var dockerInitialScript: String
    @Binding public var podmanYamlConfig: String
    @Binding public var podmanInitialScript: String

    // Shell Bindings
    @Binding public var shellRunCommand: String
    @Binding public var shellWorkingDirectory: String

    // SSH Bindings
    @Binding public var sshHost: String
    @Binding public var sshUser: String
    @Binding public var sshPort: String

    // Health Check Bindings
    @Binding public var httpCheckUrl: String
    @Binding public var httpCheckInterval: HealthCheckIntervalOption

    // Tunnel Bindings
    @Binding public var tunnelType: TunnelEngineOption
    @Binding public var tunnelTargetUrl: String
    @Binding public var ngrokAuthToken: String

    // Process Monitor Bindings
    @Binding public var monitorProcessName: String
    @Binding public var monitorInterval: HealthCheckIntervalOption

    // Port Mappings
    @Binding public var ports: [KumaPortMappingItem]

    public init(
        providerCategory: ProviderCategory,
        isEditing: Bool,
        providerLabel: Binding<String>,
        kubeConfigVM: KubeConfigViewModel? = nil,
        kubeNamespace: Binding<String>,
        kubeContext: Binding<String>,
        targetName: Binding<String>,
        kubeTargetType: Binding<KubeTargetType>,
        usePattern: Binding<Bool>,
        dockerYamlConfig: Binding<String>,
        dockerInitialScript: Binding<String>,
        podmanYamlConfig: Binding<String>,
        podmanInitialScript: Binding<String>,
        shellRunCommand: Binding<String>,
        shellWorkingDirectory: Binding<String>,
        sshHost: Binding<String>,
        sshUser: Binding<String>,
        sshPort: Binding<String>,
        httpCheckUrl: Binding<String>,
        httpCheckInterval: Binding<HealthCheckIntervalOption>,
        tunnelType: Binding<TunnelEngineOption>,
        tunnelTargetUrl: Binding<String>,
        ngrokAuthToken: Binding<String>,
        monitorProcessName: Binding<String>,
        monitorInterval: Binding<HealthCheckIntervalOption>,
        ports: Binding<[KumaPortMappingItem]>
    ) {
        self.providerCategory = providerCategory
        self.isEditing = isEditing
        self._providerLabel = providerLabel
        self.kubeConfigVM = kubeConfigVM
        self._kubeNamespace = kubeNamespace
        self._kubeContext = kubeContext
        self._targetName = targetName
        self._kubeTargetType = kubeTargetType
        self._usePattern = usePattern
        self._dockerYamlConfig = dockerYamlConfig
        self._dockerInitialScript = dockerInitialScript
        self._podmanYamlConfig = podmanYamlConfig
        self._podmanInitialScript = podmanInitialScript
        self._shellRunCommand = shellRunCommand
        self._shellWorkingDirectory = shellWorkingDirectory
        self._sshHost = sshHost
        self._sshUser = sshUser
        self._sshPort = sshPort
        self._httpCheckUrl = httpCheckUrl
        self._httpCheckInterval = httpCheckInterval
        self._tunnelType = tunnelType
        self._tunnelTargetUrl = tunnelTargetUrl
        self._ngrokAuthToken = ngrokAuthToken
        self._monitorProcessName = monitorProcessName
        self._monitorInterval = monitorInterval
        self._ports = ports
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // MARK: - Provider Custom Label (Top of Provider Config)
            KumaFormSection(
                icon: "tag.fill",
                title: "Provider",
                subtitle: "Identifier and runner type"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    KumaTextField(
                        label: "Custom Label (Optional)",
                        value: $providerLabel,
                        placeholder: "Staging"
                    )
                }
            }



            switch providerCategory {

            case .kubernetes:
                if let kubeConfigVM {
                    KubeConfigConnectionView(
                        viewModel: kubeConfigVM,
                        isLocked: !isEditing,
                        contextToTest: kubeContext,
                        onConfigChanged: {}
                    )
                    .disabled(!isEditing)

                    KumaFormSection(icon: "network", title: "Cluster Connection") {
                        KubeConnectionSettingsView(
                            kubeNamespace: $kubeNamespace,
                            kubeContext: $kubeContext,
                            availableContexts: kubeConfigVM.availableContexts
                        )
                        .disabled(!isEditing)
                    }
                    .onChange(of: kubeConfigVM.availableContexts, initial: true) { _, contexts in
                        if let active = kubeConfigVM.activeContextName, contexts.contains(active) {
                            kubeContext = active
                        } else if let first = contexts.first, !contexts.contains(kubeContext) {
                            kubeContext = first
                        }
                    }
                }


                KumaFormSection(icon: "scope", title: "Target Resource") {
                    KubeTargetSettingsView(
                        targetName: $targetName,
                        targetType: $kubeTargetType,
                        usePattern: $usePattern
                    )
                    .disabled(!isEditing)
                }


            case .docker:
                KumaFormSection(icon: "shippingbox.fill", title: "Docker Compose") {
                    DockerComposeSettingsView(yamlConfig: $dockerYamlConfig)
                        .disabled(!isEditing)
                }
                KumaFormSection(icon: "terminal.fill", title: "Initial Script") {
                    InitialScriptSettingsView(initialScript: $dockerInitialScript)
                        .disabled(!isEditing)
                }

            case .podman:
                KumaFormSection(icon: "shippingbox.fill", title: "Podman Compose") {
                    PodmanComposeSettingsView(yamlConfig: $podmanYamlConfig)
                        .disabled(!isEditing)
                }
                KumaFormSection(icon: "terminal.fill", title: "Initial Script") {
                    InitialScriptSettingsView(initialScript: $podmanInitialScript)
                        .disabled(!isEditing)
                }



            case .shell:
                KumaFormSection(icon: "terminal.fill", title: "Shell Command") {
                    ShellScriptSettingsView(runCommand: $shellRunCommand, workingDirectory: $shellWorkingDirectory)
                        .disabled(!isEditing)
                }

            case .ssh:
                KumaFormSection(icon: "network", title: "SSH Connection") {
                    SSHSettingsView(
                        sshHost: $sshHost,
                        sshPort: $sshPort,
                        sshUser: $sshUser,
                        authType: .constant(.key),
                        sshKeyPath: .constant("~/.ssh/id_ed25519"),
                        sshPassword: .constant("")
                    )
                    .disabled(!isEditing)
                }

            case .httpCheck:
                KumaFormSection(icon: "heart.text.square.fill", title: "Health Check") {
                    HealthCheckSettingsView(
                        httpCheckUrl: $httpCheckUrl,
                        checkInterval: $httpCheckInterval
                    )
                    .disabled(!isEditing)
                }

            case .tunnel:
                KumaFormSection(icon: "cloud.bolt.fill", title: "Public Tunnel") {
                    TunnelSettingsView(
                        tunnelType: $tunnelType,
                        tunnelTargetUrl: $tunnelTargetUrl,
                        ngrokAuthToken: $ngrokAuthToken
                    )
                    .disabled(!isEditing)
                }

            case .processMonitor:
                KumaFormSection(icon: "cpu.fill", title: "Process Monitor") {
                    ProcessMonitorSettingsView(
                        monitorProcessName: $monitorProcessName,
                        monitorInterval: $monitorInterval
                    )
                    .disabled(!isEditing)
                }
            }

            // Ports Section (Shown for Kubernetes and SSH, exact same as CreateServiceSheet)
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
}

