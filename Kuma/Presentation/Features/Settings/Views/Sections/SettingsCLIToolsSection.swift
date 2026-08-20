import SwiftUI
import UniformTypeIdentifiers

public struct SettingsCLIToolsSection: View {
    @Bindable var viewModel: SettingsViewModel

    // Auto-detected default paths when custom path is empty
    @State private var defaultDockerPath: String = ""
    @State private var defaultKubectlPath: String = ""
    @State private var defaultPodmanPath: String = ""

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Validation Computations (Zero-latency)

    private var kubectlValidation: BinaryValidationResult {
        DependencyChecker.validateCustomBinary(path: viewModel.customKubectlPath, expectedCommand: "kubectl")
    }

    private var isKubectlAvailable: Bool {
        if viewModel.customKubectlPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !defaultKubectlPath.isEmpty
        }
        return kubectlValidation.isValid
    }

    private var kubeconfigValidation: String? {
        let trimmed = viewModel.customKubeconfigPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let nsPath = NSString(string: trimmed).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: nsPath) {
            return "Configuration file does not exist at specified path"
        }
        return nil
    }

    private var isKubeconfigAvailable: Bool {
        if viewModel.customKubeconfigPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DependencyChecker.isKubeconfigPresent()
        }
        return kubeconfigValidation == nil
    }

    private var dockerValidation: BinaryValidationResult {
        DependencyChecker.validateCustomBinary(path: viewModel.customDockerPath, expectedCommand: "docker")
    }

    private var isDockerAvailable: Bool {
        if viewModel.customDockerPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !defaultDockerPath.isEmpty
        }
        return dockerValidation.isValid
    }

    private var podmanValidation: BinaryValidationResult {
        DependencyChecker.validateCustomBinary(path: viewModel.customPodmanPath, expectedCommand: "podman")
    }

    private var isPodmanAvailable: Bool {
        if viewModel.customPodmanPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !defaultPodmanPath.isEmpty
        }
        return podmanValidation.isValid
    }

    public var body: some View {
        KumaFormSection(
            icon: "terminal.fill",
            title: "CLI Tools"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                // Kubectl
                VStack(alignment: .leading, spacing: KumaSpacing.xs) {
                    HStack {
                        Text("Kubectl Binary")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        BinaryStatusBadge(isInstalled: isKubectlAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $viewModel.customKubectlPath,
                        placeholder: defaultKubectlPath.isEmpty ? "/opt/homebrew/bin/kubectl" : defaultKubectlPath,
                        chooseFiles: true,
                        chooseDirectories: false,
                        allowedContentTypes: [.unixExecutable, .executable],
                        error: kubectlValidation.errorMessage
                    )
                }

                Divider().opacity(0.3)

                // Default Kubeconfig Path
                VStack(alignment: .leading, spacing: KumaSpacing.xs) {
                    HStack {
                        Text("Default Kubeconfig Path")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        BinaryStatusBadge(isInstalled: isKubeconfigAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $viewModel.customKubeconfigPath,
                        placeholder: "~/.kube/config",
                        chooseFiles: true,
                        chooseDirectories: false,
                        error: kubeconfigValidation
                    )
                }

                Divider().opacity(0.3)

                // Docker
                VStack(alignment: .leading, spacing: KumaSpacing.xs) {
                    HStack {
                        Text("Docker Binary")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        BinaryStatusBadge(isInstalled: isDockerAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $viewModel.customDockerPath,
                        placeholder: defaultDockerPath.isEmpty ? "/usr/local/bin/docker" : defaultDockerPath,
                        chooseFiles: true,
                        chooseDirectories: false,
                        allowedContentTypes: [.unixExecutable, .executable],
                        error: dockerValidation.errorMessage
                    )
                }

                Divider().opacity(0.3)

                // Podman
                VStack(alignment: .leading, spacing: KumaSpacing.xs) {
                    HStack {
                        Text("Podman Binary")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        BinaryStatusBadge(isInstalled: isPodmanAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $viewModel.customPodmanPath,
                        placeholder: defaultPodmanPath.isEmpty ? "/opt/homebrew/bin/podman" : defaultPodmanPath,
                        chooseFiles: true,
                        chooseDirectories: false,
                        allowedContentTypes: [.unixExecutable, .executable],
                        error: podmanValidation.errorMessage
                    )
                }

                Divider().opacity(0.3)

                // Default Shell
                KumaRowPickerField(
                    label: "Default Shell",
                    description: "The shell to use when executing custom shell processes.",
                    options: DefaultShell.allCases.map(\.rawValue),
                    selection: $viewModel.defaultShell,
                    titleResolver: { (DefaultShell(rawValue: $0) ?? .zsh).label }
                )
            }
        }
        .task {
            await refreshDefaultPaths()
        }
    }

    private func refreshDefaultPaths() async {
        let resolver = EnvironmentPathResolver.shared
        let docker = await resolver.resolveExecutablePath(for: "docker")
        let kube = await resolver.resolveExecutablePath(for: "kubectl")
        let podman = await resolver.resolveExecutablePath(for: "podman")
        await MainActor.run {
            self.defaultDockerPath = docker ?? ""
            self.defaultKubectlPath = kube ?? ""
            self.defaultPodmanPath = podman ?? ""
        }
    }
}

