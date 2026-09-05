import Foundation
import Testing
@testable import Kuma

@Suite("Settings Category C: Concurrency, Mutations & Legacy Fallbacks", .serialized)
@MainActor
struct SettingsPersistenceAndSyncTests {

    // MARK: - [TC-C01] Property Mutation Persists To UserDefaults
    @Test("TC-C01: Mutating property updates underlying UserDefaults immediately")
    func testPropertyMutationPersistsToUserDefaults() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)

        // Mutate autoResumeServices
        viewModel.autoResumeServices = false
        #expect(harness.userDefaults.bool(forKey: KumaSettingsKey.autoResumeServices) == false)

        // Mutate confirmBeforeQuit
        viewModel.confirmBeforeQuit = false
        #expect(harness.userDefaults.bool(forKey: KumaSettingsKey.confirmBeforeQuit) == false)

        // Mutate defaultShell
        viewModel.defaultShell = "/bin/bash"
        #expect(harness.userDefaults.string(forKey: KumaSettingsKey.defaultShell) == "/bin/bash")

        // Mutate logRetentionLimit
        viewModel.logRetentionLimit = .hundredMB
        #expect(harness.userDefaults.integer(forKey: KumaSettingsKey.logRetentionLimit) == 100)
    }

    // MARK: - [TC-C02] Legacy Kubectl Path Fallback
    @Test("TC-C02: Primary key empty falls back to legacy kubectl path")
    func testLegacyKubectlPathFallback() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        harness.userDefaults.set("/opt/legacy/bin/kubectl", forKey: KumaSettingsKey.legacyKubectlPath)
        let resolved = KumaSettingsKey.string(
            forKey: KumaSettingsKey.customKubectlPath,
            fallbackKey: KumaSettingsKey.legacyKubectlPath,
            defaults: harness.userDefaults
        )

        #expect(resolved == "/opt/legacy/bin/kubectl")

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)
        #expect(viewModel.customKubectlPath == "/opt/legacy/bin/kubectl")
    }

    // MARK: - [TC-C03] Legacy Docker Path Fallback
    @Test("TC-C03: Primary key empty falls back to legacy docker path")
    func testLegacyDockerPathFallback() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        harness.userDefaults.set("/usr/local/legacy/docker", forKey: KumaSettingsKey.legacyDockerPath)
        let resolved = KumaSettingsKey.string(
            forKey: KumaSettingsKey.customDockerPath,
            fallbackKey: KumaSettingsKey.legacyDockerPath,
            defaults: harness.userDefaults
        )

        #expect(resolved == "/usr/local/legacy/docker")

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)
        #expect(viewModel.customDockerPath == "/usr/local/legacy/docker")
    }

    // MARK: - [TC-C04] Legacy Cloudflared Path Fallback
    @Test("TC-C04: Primary key empty falls back to legacy cloudflared path")
    func testLegacyCloudflaredPathFallback() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        harness.userDefaults.set("/opt/homebrew/bin/legacy_cloudflared", forKey: KumaSettingsKey.legacyCloudflaredPath)
        let resolved = KumaSettingsKey.string(
            forKey: KumaSettingsKey.cloudflaredPath,
            fallbackKey: KumaSettingsKey.legacyCloudflaredPath,
            defaults: harness.userDefaults
        )

        #expect(resolved == "/opt/homebrew/bin/legacy_cloudflared")

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)
        #expect(viewModel.cloudflaredPath == "/opt/homebrew/bin/legacy_cloudflared")
    }

    // MARK: - [TC-C05] Primary Key Overrides Legacy Key
    @Test("TC-C05: Primary key takes precedence over legacy key when both are present")
    func testPrimaryKeyOverridesLegacyKey() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        harness.userDefaults.set("/usr/local/bin/modern_podman", forKey: KumaSettingsKey.customPodmanPath)
        harness.userDefaults.set("/usr/local/bin/legacy_podman", forKey: KumaSettingsKey.legacyPodmanPath)

        let resolved = KumaSettingsKey.string(
            forKey: KumaSettingsKey.customPodmanPath,
            fallbackKey: KumaSettingsKey.legacyPodmanPath,
            defaults: harness.userDefaults
        )

        #expect(resolved == "/usr/local/bin/modern_podman")

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)
        #expect(viewModel.customPodmanPath == "/usr/local/bin/modern_podman")
    }

    // MARK: - [TC-C06] Concurrent Settings Updates
    @Test("TC-C06: Concurrent updates to separate settings properties execute deterministically")
    func testConcurrentSettingsUpdates() async {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                viewModel.notifyOnCrash = false
            }
            group.addTask { @MainActor in
                viewModel.notifySound = false
            }
            group.addTask { @MainActor in
                viewModel.warnOnPortCollision = false
            }
        }

        #expect(viewModel.notifyOnCrash == false)
        #expect(viewModel.notifySound == false)
        #expect(viewModel.warnOnPortCollision == false)
    }
}
