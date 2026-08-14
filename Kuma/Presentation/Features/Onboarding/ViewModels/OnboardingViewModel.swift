//
//  OnboardingViewModel.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Clean @Observable state management for the multi-step Onboarding Wizard.
//

import Foundation
import Observation

@Observable
@MainActor
public final class OnboardingViewModel {
    public var currentStep: Int = 0
    public var isScanning: Bool = false
    public var hasInitialScanned: Bool = false

    public var engineDependencies: [SystemDependency] = []
    public var tunnelingDependencies: [SystemDependency] = []

    public let totalSteps: Int = 4 // 0: Welcome, 1: Engines, 2: Tunneling, 3: Ready

    public init() {}

    /// Performs dependency scan only if not already scanned or when explicitly requested.
    public func scanDependenciesIfNeeded(force: Bool = false) async {
        guard !hasInitialScanned || force else { return }
        await runScan(isManualRescan: force)
    }

    /// Executes system scan across all CLI engines and tunneling tools.
    public func runScan(isManualRescan: Bool = false) async {
        guard !isScanning else { return }
        isScanning = true

        let status = await DependencyChecker.checkAll()

        async let kubectlPath = DependencyChecker.resolvedPath(for: "kubectl")
        async let dockerPath = DependencyChecker.resolvedPath(for: "docker")
        async let podmanPath = DependencyChecker.resolvedPath(for: "podman")
        async let cloudflaredPath = DependencyChecker.resolvedPath(for: "cloudflared")
        async let ngrokPath = DependencyChecker.resolvedPath(for: "ngrok")

        let paths = await (kubectlPath, dockerPath, podmanPath, cloudflaredPath, ngrokPath)

        if isManualRescan {
            // Subtle 300ms throttle for visual tactile feedback on button click
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        self.engineDependencies = [
            SystemDependency(
                id: "kubectl",
                name: "Kubernetes CLI (kubectl)",
                iconName: "network",
                isInstalled: status.kubectlInstalled,
                path: paths.0,
                category: .engine,
                description: "Enables Kubernetes Port-Forward provider",
                settingsKey: "kuma.custom_kubectl_path"
            ),
            SystemDependency(
                id: "kubeconfig",
                name: "Kubeconfig File",
                iconName: "doc.text.fill",
                isInstalled: status.kubeconfigExists,
                path: status.kubeconfigExists ? "~/.kube/config" : nil,
                category: .engine,
                description: "Cluster configuration for Kubernetes",
                settingsKey: "kuma.custom_kubeconfig_path"
            ),
            SystemDependency(
                id: "docker",
                name: "Docker Engine & Compose",
                iconName: "shippingbox.fill",
                isInstalled: status.dockerInstalled,
                path: paths.1,
                category: .engine,
                description: "Enables Docker Compose provider",
                settingsKey: "kuma.custom_docker_path"
            ),
            SystemDependency(
                id: "podman",
                name: "Podman Engine",
                iconName: "cylinder.split.1x2.fill",
                isInstalled: status.podmanInstalled,
                path: paths.2,
                category: .engine,
                description: "Enables Podman Compose provider",
                settingsKey: "kuma.custom_podman_path"
            )
        ]

        self.tunnelingDependencies = [
            SystemDependency(
                id: "cloudflared",
                name: "Cloudflare Tunnel (cloudflared)",
                iconName: "cloud.bolt.fill",
                isInstalled: status.cloudflaredInstalled,
                path: paths.3,
                category: .tunneling,
                description: "Enables Public Tunnel via Cloudflare",
                settingsKey: "kuma.custom_cloudflared_path"
            ),
            SystemDependency(
                id: "ngrok",
                name: "ngrok Tunnel",
                iconName: "globe",
                isInstalled: status.ngrokInstalled,
                path: paths.4,
                category: .tunneling,
                description: "Enables Public Tunnel via ngrok",
                settingsKey: "kuma.custom_ngrok_path"
            )
        ]

        self.hasInitialScanned = true
        self.isScanning = false
    }

    /// Sets custom override path for a given dependency and triggers non-blocking re-scan.
    public func setCustomPath(for dependency: SystemDependency, path: String) {
        UserDefaults.standard.set(path, forKey: dependency.settingsKey)
        Task {
            await runScan(isManualRescan: false)
        }
    }

    public func nextStep() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }

    public func prevStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
}
