import Foundation
import Testing
@testable import Kuma

@Suite("Settings Category A: Initial State & Baseline Contracts", .serialized)
@MainActor
struct SettingsInitialStateTests {

    // MARK: - [TC-A01] Clean Install Default General Settings
    @Test("TC-A01: Fresh install initializes general preferences with safe baseline contracts")
    func testDefaultGeneralSettings() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)

        #expect(viewModel.launchAtLogin == false)
        #expect(viewModel.autoResumeServices == true)
        #expect(viewModel.confirmBeforeQuit == true)
    }

    // MARK: - [TC-A02] Clean Install Default Appearance
    @Test("TC-A02: Fresh install initializes appearance with system default theme")
    func testDefaultAppearance() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)

        #expect(viewModel.appearance == .system)
        #expect(viewModel.appearance.title == "System Default")
        #expect(KumaAppearance.allCases.count == 3)
    }

    // MARK: - [TC-A03] Clean Install Default Engine & CLI Paths
    @Test("TC-A03: Fresh install leaves custom CLI override paths empty")
    func testDefaultEnginePaths() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)

        #expect(viewModel.customPathOverride.isEmpty)
        #expect(viewModel.customKubectlPath.isEmpty)
        #expect(viewModel.customKubeconfigPath.isEmpty)
        #expect(viewModel.customDockerPath.isEmpty)
        #expect(viewModel.customPodmanPath.isEmpty)
        #expect(viewModel.cloudflaredPath.isEmpty)
        #expect(viewModel.customNgrokPath.isEmpty)
    }

    // MARK: - [TC-A04] Clean Install Default Shell
    @Test("TC-A04: Fresh install defaults to /bin/zsh shell")
    func testDefaultShellOption() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)

        #expect(viewModel.defaultShell == "/bin/zsh")
        #expect(DefaultShell.zsh.label == "Zsh")
        #expect(DefaultShell.bash.label == "Bash")
        #expect(DefaultShell.fish.label == "Fish")
    }

    // MARK: - [TC-A05] Clean Install Default Notification & Safety
    @Test("TC-A05: Fresh install initializes safety toggles to enabled")
    func testDefaultNotificationSettings() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)

        #expect(viewModel.notifyOnCrash == true)
        #expect(viewModel.notifySound == true)
        #expect(viewModel.notifyOnHealthFailure == true)
        #expect(viewModel.warnOnPortCollision == true)
        #expect(viewModel.promptGracefulShutdown == true)
    }

    // MARK: - [TC-A06] Clean Install Default Log Retention
    @Test("TC-A06: Fresh install defaults to 50MB log buffer limit and false clearLogsOnSwitch")
    func testDefaultLogRetention() {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        let viewModel = SettingsViewModel(userDefaults: harness.userDefaults)

        #expect(viewModel.logRetentionLimit == .fiftyMB)
        #expect(viewModel.logRetentionLimit.title == "50 MB")
        #expect(viewModel.clearLogsOnSwitch == false)
    }
}
