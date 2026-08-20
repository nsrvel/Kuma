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

    /// Executes system scan across all CLI engines and tunneling tools in a single unified pass.
    public func runScan(isManualRescan: Bool = false) async {
        guard !isScanning else { return }
        isScanning = true

        let customKubectl = UserDefaults.standard.string(forKey: "kuma.custom_kubectl_path")
        let customKubeconfig = UserDefaults.standard.string(forKey: "kuma.custom_kubeconfig_path")
        let customDocker = UserDefaults.standard.string(forKey: "kuma.custom_docker_path")
        let customPodman = UserDefaults.standard.string(forKey: "kuma.custom_podman_path")
        let customCloudflared = UserDefaults.standard.string(forKey: "kuma.custom_cloudflared_path")
        let customNgrok = UserDefaults.standard.string(forKey: "kuma.custom_ngrok_path")

        async let kubectlPath = DependencyChecker.resolvedPath(for: "kubectl", customPath: customKubectl)
        async let dockerPath = DependencyChecker.resolvedPath(for: "docker", customPath: customDocker)
        async let podmanPath = DependencyChecker.resolvedPath(for: "podman", customPath: customPodman)
        async let cloudflaredPath = DependencyChecker.resolvedPath(for: "cloudflared", customPath: customCloudflared)
        async let ngrokPath = DependencyChecker.resolvedPath(for: "ngrok", customPath: customNgrok)
        let isKubeconfigPresent = DependencyChecker.isKubeconfigPresent(customPath: customKubeconfig)

        let paths = await (kubectlPath, dockerPath, podmanPath, cloudflaredPath, ngrokPath)

        if isManualRescan {
            // Subtle 200ms throttle for visual tactile feedback on button click
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        self.engineDependencies = [
            SystemDependency(
                id: "kubectl",
                name: "Kubernetes CLI (kubectl)",
                iconName: "network",
                isInstalled: paths.0 != nil,
                path: paths.0,
                category: .engine,
                description: "Enables Kubernetes provider",
                settingsKey: "kuma.custom_kubectl_path"
            ),
            SystemDependency(
                id: "kubeconfig",
                name: "Kubeconfig File",
                iconName: "doc.text.fill",
                isInstalled: isKubeconfigPresent,
                path: isKubeconfigPresent ? (customKubeconfig ?? "~/.kube/config") : nil,
                category: .engine,
                description: "Cluster configuration for Kubernetes",
                settingsKey: "kuma.custom_kubeconfig_path"
            ),
            SystemDependency(
                id: "docker",
                name: "Docker Engine",
                iconName: "shippingbox.fill",
                isInstalled: paths.1 != nil,
                path: paths.1,
                category: .engine,
                description: "Enables Docker provider",
                settingsKey: "kuma.custom_docker_path"
            ),
            SystemDependency(
                id: "podman",
                name: "Podman Engine",
                iconName: "cylinder.split.1x2.fill",
                isInstalled: paths.2 != nil,
                path: paths.2,
                category: .engine,
                description: "Enables Podman provider",
                settingsKey: "kuma.custom_podman_path"
            )
        ]

        self.tunnelingDependencies = [
            SystemDependency(
                id: "cloudflared",
                name: "Cloudflare Tunnel (cloudflared)",
                iconName: "cloud.bolt.fill",
                isInstalled: paths.3 != nil,
                path: paths.3,
                category: .tunneling,
                description: "Enables Tunnel via Cloudflare",
                settingsKey: "kuma.custom_cloudflared_path"
            ),
            SystemDependency(
                id: "ngrok",
                name: "ngrok Tunnel",
                iconName: "globe",
                isInstalled: paths.4 != nil,
                path: paths.4,
                category: .tunneling,
                description: "Enables Tunnel via ngrok",
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
