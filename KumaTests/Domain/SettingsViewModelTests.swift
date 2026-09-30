import Testing
import Foundation
@testable import Kuma

@Suite("SettingsViewModel Tests")
@MainActor
struct SettingsViewModelTests {

    private func createIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "kuma.test.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, suiteName)
    }

    @Test("SettingsViewModel initializes with standard defaults")
    func testInitializationDefaults() {
        let (defaults, suiteName) = createIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let store = SettingsViewModel(userDefaults: defaults)

        #expect(store.launchAtLogin == false)
        #expect(store.autoResumeServices == true)
        #expect(store.confirmBeforeQuit == true)
        #expect(store.appearance == .system)
        #expect(store.notifyOnCrash == true)
        #expect(store.notifyOnHealthFailure == true)
        #expect(store.warnOnPortCollision == true)
        #expect(store.promptGracefulShutdown == true)
        #expect(store.logRetentionLimit == .fiftyMB)
        #expect(store.defaultShell == "/bin/zsh")
    }

    @Test("SettingsViewModel updates and persists property mutations")
    func testPersistence() {
        let (defaults, suiteName) = createIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let store = SettingsViewModel(userDefaults: defaults)

        store.autoResumeServices = false
        store.confirmBeforeQuit = false
        store.appearance = .dark
        store.customPathOverride = "/custom/bin:/opt/bin"
        store.ngrokAuthToken = "secret_token_123"
        store.ngrokRegion = "ap"
        store.logRetentionLimit = .hundredMB

        #expect(defaults.bool(forKey: SettingsViewModel.Keys.autoResumeServices) == false)
        #expect(defaults.bool(forKey: SettingsViewModel.Keys.confirmBeforeQuit) == false)
        #expect(defaults.string(forKey: SettingsViewModel.Keys.appearance) == "dark")
        #expect(defaults.string(forKey: SettingsViewModel.Keys.customPathOverride) == "/custom/bin:/opt/bin")
        #expect(defaults.string(forKey: SettingsViewModel.Keys.ngrokAuthToken) == "secret_token_123")
        #expect(defaults.string(forKey: SettingsViewModel.Keys.ngrokRegion) == "ap")
        #expect(defaults.integer(forKey: SettingsViewModel.Keys.logRetentionLimit) == 100)
    }
}
