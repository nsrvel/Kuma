//
//  SettingsCLIToolsSection.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect CLI Tools Section with Live Status Badges & Browse Pickers.
//

import SwiftUI
import UniformTypeIdentifiers

public struct SettingsCLIToolsSection: View {
    @Bindable var store: SettingsStore

    // Auto-detected default paths when custom path is empty
    @State private var defaultDockerPath: String = ""
    @State private var defaultKubectlPath: String = ""
    @State private var defaultPodmanPath: String = ""

    public init(store: SettingsStore) {
        self.store = store
    }

    // MARK: - Validation Computations (Zero-latency)

    private var kubectlValidation: BinaryValidationResult {
        DependencyChecker.validateCustomBinary(path: store.customKubectlPath, expectedCommand: "kubectl")
    }

    private var isKubectlAvailable: Bool {
        if store.customKubectlPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !defaultKubectlPath.isEmpty
        }
        return kubectlValidation.isValid
    }

    private var kubeconfigValidation: String? {
        let trimmed = store.customKubeconfigPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let nsPath = NSString(string: trimmed).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: nsPath) {
            return "Configuration file does not exist at specified path"
        }
        return nil
    }

    private var isKubeconfigAvailable: Bool {
        if store.customKubeconfigPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DependencyChecker.isKubeconfigPresent()
        }
        return kubeconfigValidation == nil
    }

    private var dockerValidation: BinaryValidationResult {
        DependencyChecker.validateCustomBinary(path: store.customDockerPath, expectedCommand: "docker")
    }

    private var isDockerAvailable: Bool {
        if store.customDockerPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !defaultDockerPath.isEmpty
        }
        return dockerValidation.isValid
    }

    private var podmanValidation: BinaryValidationResult {
        DependencyChecker.validateCustomBinary(path: store.customPodmanPath, expectedCommand: "podman")
    }

    private var isPodmanAvailable: Bool {
        if store.customPodmanPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                        statusBadge(isInstalled: isKubectlAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $store.customKubectlPath,
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
                        statusBadge(isInstalled: isKubeconfigAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $store.customKubeconfigPath,
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
                        statusBadge(isInstalled: isDockerAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $store.customDockerPath,
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
                        statusBadge(isInstalled: isPodmanAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $store.customPodmanPath,
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
                    selection: $store.defaultShell,
                    titleResolver: { (DefaultShell(rawValue: $0) ?? .zsh).label }
                )
            }
        }
        .task {
            await refreshDefaultPaths()
        }
    }

    @ViewBuilder
    private func statusBadge(isInstalled: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isInstalled ? Color.green : Color.red.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(isInstalled ? "Available" : "Not Found")
                .font(KumaFont.caption)
                .foregroundStyle(isInstalled ? Color.secondary : Color.red.opacity(0.8))
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
