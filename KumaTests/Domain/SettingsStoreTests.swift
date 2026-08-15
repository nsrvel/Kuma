//
//  SettingsStoreTests.swift
//  KumaTests
//
//  Created for Kuma Native macOS App.
//

import Testing
import Foundation
@testable import Kuma

@Suite("SettingsStore Tests")
@MainActor
struct SettingsStoreTests {

    private func createIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "kuma.test.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, suiteName)
    }

    @Test("SettingsStore initializes with standard defaults")
    func testInitializationDefaults() {
        let (defaults, suiteName) = createIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(userDefaults: defaults)

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

    @Test("SettingsStore updates and persists property mutations")
    func testPersistence() {
        let (defaults, suiteName) = createIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(userDefaults: defaults)

        store.autoResumeServices = false
        store.confirmBeforeQuit = false
        store.appearance = .dark
        store.customPathOverride = "/custom/bin:/opt/bin"
        store.ngrokAuthToken = "secret_token_123"
        store.ngrokRegion = "ap"
        store.logRetentionLimit = .hundredMB

        #expect(defaults.bool(forKey: SettingsStore.Keys.autoResumeServices) == false)
        #expect(defaults.bool(forKey: SettingsStore.Keys.confirmBeforeQuit) == false)
        #expect(defaults.string(forKey: SettingsStore.Keys.appearance) == "dark")
        #expect(defaults.string(forKey: SettingsStore.Keys.customPathOverride) == "/custom/bin:/opt/bin")
        #expect(defaults.string(forKey: SettingsStore.Keys.ngrokAuthToken) == "secret_token_123")
        #expect(defaults.string(forKey: SettingsStore.Keys.ngrokRegion) == "ap")
        #expect(defaults.integer(forKey: SettingsStore.Keys.logRetentionLimit) == 100)
    }
}
