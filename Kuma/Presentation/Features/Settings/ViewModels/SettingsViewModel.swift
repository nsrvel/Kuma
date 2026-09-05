import SwiftUI
import Observation
import ServiceManagement
import UserNotifications
import os

public enum KumaAppearance: String, CaseIterable, Codable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var title: String {
        switch self {
        case .system: return "System Default"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

public enum DefaultShell: String, CaseIterable, Codable, Sendable {
    case zsh = "/bin/zsh"
    case bash = "/bin/bash"
    case fish = "/opt/homebrew/bin/fish"

    public var label: String {
        switch self {
        case .zsh: return "Zsh"
        case .bash: return "Bash"
        case .fish: return "Fish"
        }
    }
}

public enum LogRetentionLimit: Int, CaseIterable, Codable, Sendable {
    case tenMB = 10
    case fiftyMB = 50
    case hundredMB = 100
    case unlimited = 0

    public var title: String {
        switch self {
        case .tenMB: return "10 MB"
        case .fiftyMB: return "50 MB"
        case .hundredMB: return "100 MB"
        case .unlimited: return "Unlimited"
        }
    }
}

public enum PortConflictPolicy: String, CaseIterable, Codable, Sendable {
    case warnAndBlock = "warn_and_block"
    case killExisting = "kill_existing"

    public var title: String {
        switch self {
        case .warnAndBlock: return "Warn & Prevent Start"
        case .killExisting: return "Kill Conflicting Process"
        }
    }
}

@MainActor
@Observable
public final class SettingsViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "SettingsViewModel")
    private let userDefaults: UserDefaults

    // MARK: - Keys (Centralized)
    public typealias Keys = KumaSettingsKey

    // MARK: - General Settings

    public var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    public var autoResumeServices: Bool {
        didSet { userDefaults.set(autoResumeServices, forKey: Keys.autoResumeServices) }
    }

    public var confirmBeforeQuit: Bool {
        didSet { userDefaults.set(confirmBeforeQuit, forKey: Keys.confirmBeforeQuit) }
    }

    public var appearance: KumaAppearance {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance(appearance)
        }
    }

    // MARK: - Engine & CLI Settings

    public var customPathOverride: String {
        didSet { userDefaults.set(customPathOverride, forKey: Keys.customPathOverride) }
    }

    public var defaultShell: String {
        didSet { userDefaults.set(defaultShell, forKey: Keys.defaultShell) }
    }

    public var customKubectlPath: String {
        didSet { userDefaults.set(customKubectlPath, forKey: Keys.customKubectlPath) }
    }

    public var customKubeconfigPath: String {
        didSet { userDefaults.set(customKubeconfigPath, forKey: Keys.customKubeconfigPath) }
    }

    public var customDockerPath: String {
        didSet { userDefaults.set(customDockerPath, forKey: Keys.customDockerPath) }
    }

    public var customPodmanPath: String {
        didSet { userDefaults.set(customPodmanPath, forKey: Keys.customPodmanPath) }
    }

    // MARK: - Tunnels Settings

    public var cloudflaredPath: String {
        didSet { userDefaults.set(cloudflaredPath, forKey: Keys.cloudflaredPath) }
    }

    public var customNgrokPath: String {
        didSet { userDefaults.set(customNgrokPath, forKey: Keys.customNgrokPath) }
    }

    public var ngrokAuthToken: String {
        didSet { userDefaults.set(ngrokAuthToken, forKey: Keys.ngrokAuthToken) }
    }

    public var ngrokRegion: String {
        didSet { userDefaults.set(ngrokRegion, forKey: Keys.ngrokRegion) }
    }

    // MARK: - Notifications & Safety

    public var notifyOnCrash: Bool {
        didSet { userDefaults.set(notifyOnCrash, forKey: Keys.notifyOnCrash) }
    }

    public var notifySound: Bool {
        didSet { userDefaults.set(notifySound, forKey: Keys.notifySound) }
    }

    public var notifyOnHealthFailure: Bool {
        didSet { userDefaults.set(notifyOnHealthFailure, forKey: Keys.notifyOnHealthFailure) }
    }

    public var warnOnPortCollision: Bool {
        didSet { userDefaults.set(warnOnPortCollision, forKey: Keys.warnOnPortCollision) }
    }

    public var portConflictPolicy: PortConflictPolicy {
        didSet { userDefaults.set(portConflictPolicy.rawValue, forKey: Keys.portConflictPolicy) }
    }

    public var promptGracefulShutdown: Bool {
        didSet { userDefaults.set(promptGracefulShutdown, forKey: Keys.promptGracefulShutdown) }
    }

    // MARK: - Advanced & Data

    public var logRetentionLimit: LogRetentionLimit {
        didSet { userDefaults.set(logRetentionLimit.rawValue, forKey: Keys.logRetentionLimit) }
    }

    public var clearLogsOnSwitch: Bool {
        didSet { userDefaults.set(clearLogsOnSwitch, forKey: Keys.clearLogsOnSwitch) }
    }

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        self.launchAtLogin = userDefaults.bool(forKey: Keys.launchAtLogin)
        self.autoResumeServices = KumaSettingsKey.bool(forKey: Keys.autoResumeServices, defaultValue: true, defaults: userDefaults)
        self.confirmBeforeQuit = KumaSettingsKey.bool(forKey: Keys.confirmBeforeQuit, defaultValue: true, defaults: userDefaults)

        let rawAppearance = userDefaults.string(forKey: Keys.appearance) ?? KumaAppearance.system.rawValue
        self.appearance = KumaAppearance(rawValue: rawAppearance) ?? .system

        self.customPathOverride = userDefaults.string(forKey: Keys.customPathOverride) ?? ""
        self.defaultShell = userDefaults.string(forKey: Keys.defaultShell) ?? "/bin/zsh"

        self.customKubectlPath = KumaSettingsKey.string(
            forKey: Keys.customKubectlPath,
            fallbackKey: Keys.legacyKubectlPath,
            defaults: userDefaults
        ) ?? ""

        self.customKubeconfigPath = KumaSettingsKey.string(
            forKey: Keys.customKubeconfigPath,
            fallbackKey: Keys.legacyKubeconfigPath,
            defaults: userDefaults
        ) ?? ""

        self.customDockerPath = KumaSettingsKey.string(
            forKey: Keys.customDockerPath,
            fallbackKey: Keys.legacyDockerPath,
            defaults: userDefaults
        ) ?? ""

        self.customPodmanPath = KumaSettingsKey.string(
            forKey: Keys.customPodmanPath,
            fallbackKey: Keys.legacyPodmanPath,
            defaults: userDefaults
        ) ?? ""

        self.cloudflaredPath = KumaSettingsKey.string(
            forKey: Keys.cloudflaredPath,
            fallbackKey: Keys.legacyCloudflaredPath,
            defaults: userDefaults
        ) ?? ""

        self.customNgrokPath = KumaSettingsKey.string(
            forKey: Keys.customNgrokPath,
            fallbackKey: Keys.legacyNgrokPath,
            defaults: userDefaults
        ) ?? ""

        self.ngrokAuthToken = userDefaults.string(forKey: Keys.ngrokAuthToken) ?? ""
        self.ngrokRegion = userDefaults.string(forKey: Keys.ngrokRegion) ?? "auto"

        self.notifyOnCrash = KumaSettingsKey.bool(forKey: Keys.notifyOnCrash, defaultValue: true, defaults: userDefaults)
        self.notifySound = KumaSettingsKey.bool(forKey: Keys.notifySound, defaultValue: true, defaults: userDefaults)
        self.notifyOnHealthFailure = KumaSettingsKey.bool(forKey: Keys.notifyOnHealthFailure, defaultValue: true, defaults: userDefaults)
        self.warnOnPortCollision = KumaSettingsKey.bool(forKey: Keys.warnOnPortCollision, defaultValue: true, defaults: userDefaults)
        let rawPortPolicy = userDefaults.string(forKey: Keys.portConflictPolicy) ?? PortConflictPolicy.warnAndBlock.rawValue
        self.portConflictPolicy = PortConflictPolicy(rawValue: rawPortPolicy) ?? .warnAndBlock
        self.promptGracefulShutdown = KumaSettingsKey.bool(forKey: Keys.promptGracefulShutdown, defaultValue: true, defaults: userDefaults)

        if let savedLimit = userDefaults.object(forKey: Keys.logRetentionLimit) as? Int,
           let limit = LogRetentionLimit(rawValue: savedLimit) {
            self.logRetentionLimit = limit
        } else {
            self.logRetentionLimit = .fiftyMB
        }
        self.clearLogsOnSwitch = userDefaults.bool(forKey: Keys.clearLogsOnSwitch)

        // Apply appearance theme immediately on initialization
        applyAppearance(self.appearance)
    }

    // MARK: - System Actions

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.logger.error("Failed to toggle launch at login: \(error.localizedDescription)")
        }
    }

    public func applyAppearance(_ appearance: KumaAppearance) {
        guard let app = NSApplication.sharedIfRunning else { return }
        switch appearance {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .aqua)
        case .dark:
            app.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Requests UNUserNotificationCenter authorization asynchronously with coordinated state updates.
    /// Returns true if an external macOS System Settings prompt dialog should be shown to the user.
    public func requestNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                self.notifyOnCrash = granted
                return !granted
            } catch {
                self.notifyOnCrash = false
                return false
            }
        case .denied:
            self.notifyOnCrash = false
            return true
        case .authorized, .provisional, .ephemeral:
            self.notifyOnCrash = true
            return false
        @unknown default:
            return false
        }
    }

    /// Resets all preferences and binary paths to factory defaults in UserDefaults.
    /// Workspaces, services, credentials and database records are NOT deleted.
    public func resetSettingsToDefault() {
        let allKeys = [
            Keys.launchAtLogin,
            Keys.autoResumeServices,
            Keys.confirmBeforeQuit,
            Keys.appearance,
            Keys.customPathOverride,
            Keys.defaultShell,
            Keys.customKubectlPath,
            Keys.customKubeconfigPath,
            Keys.customDockerPath,
            Keys.customPodmanPath,
            Keys.cloudflaredPath,
            Keys.customNgrokPath,
            Keys.ngrokAuthToken,
            Keys.ngrokRegion,
            Keys.notifyOnCrash,
            Keys.notifySound,
            Keys.notifyOnHealthFailure,
            Keys.warnOnPortCollision,
            Keys.portConflictPolicy,
            Keys.promptGracefulShutdown,
            Keys.logRetentionLimit,
            Keys.clearLogsOnSwitch,
            Keys.legacyKubectlPath,
            Keys.legacyKubeconfigPath,
            Keys.legacyDockerPath,
            Keys.legacyPodmanPath,
            Keys.legacyCloudflaredPath,
            Keys.legacyNgrokPath
        ]

        for key in allKeys {
            userDefaults.removeObject(forKey: key)
        }

        // Re-assign default values to in-memory properties
        self.launchAtLogin = false
        self.autoResumeServices = true
        self.confirmBeforeQuit = true
        self.appearance = .system
        self.customPathOverride = ""
        self.defaultShell = "/bin/zsh"
        self.customKubectlPath = ""
        self.customKubeconfigPath = ""
        self.customDockerPath = ""
        self.customPodmanPath = ""
        self.cloudflaredPath = ""
        self.customNgrokPath = ""
        self.ngrokAuthToken = ""
        self.ngrokRegion = "auto"
        self.notifyOnCrash = true
        self.notifySound = true
        self.notifyOnHealthFailure = true
        self.warnOnPortCollision = true
        self.portConflictPolicy = .warnAndBlock
        self.promptGracefulShutdown = true
        self.logRetentionLimit = .fiftyMB
        self.clearLogsOnSwitch = false

        applyAppearance(.system)
        Self.logger.info("All user settings successfully reset to factory defaults.")
    }
}

