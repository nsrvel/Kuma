import Foundation

/// Centralized configuration keys for user preferences, persistent settings, and binary paths.
/// Eliminates hardcoded magic strings and prevents typo-induced state desync across features.
public enum KumaSettingsKey {
    // MARK: - App & Lifecycle
    public static let hasCompletedOnboarding = "kuma.has_completed_onboarding"

    // MARK: - Engine Custom Binary Paths
    public static let customKubectlPath = "kuma.settings.customKubectlPath"
    public static let customKubeconfigPath = "kuma.settings.customKubeconfigPath"
    public static let customDockerPath = "kuma.settings.customDockerPath"
    public static let customPodmanPath = "kuma.settings.customPodmanPath"

    // MARK: - Tunneling Custom Binary Paths
    public static let cloudflaredPath = "kuma.settings.cloudflaredPath"
    public static let customNgrokPath = "kuma.settings.customNgrokPath"

    // MARK: - Legacy Compatibility Keys (Fallback reading)
    public static let legacyKubectlPath = "kuma.custom_kubectl_path"
    public static let legacyKubeconfigPath = "kuma.custom_kubeconfig_path"
    public static let legacyDockerPath = "kuma.custom_docker_path"
    public static let legacyPodmanPath = "kuma.custom_podman_path"
    public static let legacyCloudflaredPath = "kuma.custom_cloudflared_path"
    public static let legacyNgrokPath = "kuma.custom_ngrok_path"

    /// Helper to resolve a string preference checking new key first, then legacy key fallback.
    public static func string(forKey primaryKey: String, fallbackKey: String? = nil, defaults: UserDefaults = .standard) -> String? {
        if let val = defaults.string(forKey: primaryKey), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return val
        }
        if let fallbackKey, let fallbackVal = defaults.string(forKey: fallbackKey), !fallbackVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallbackVal
        }
        return nil
    }
}
