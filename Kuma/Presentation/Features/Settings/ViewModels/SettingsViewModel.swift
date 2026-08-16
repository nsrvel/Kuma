import SwiftUI
import Observation
import ServiceManagement
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

@MainActor
@Observable
public final class SettingsViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "SettingsViewModel")
    private let userDefaults: UserDefaults

    // MARK: - Keys

    public enum Keys {
        public static let launchAtLogin = "kuma.settings.launchAtLogin"
        public static let autoResumeServices = "kuma.settings.autoResumeServices"
        public static let confirmBeforeQuit = "kuma.settings.confirmBeforeQuit"
        public static let appearance = "kuma.settings.appearance"
        public static let customPathOverride = "kuma.settings.customPathOverride"
        public static let defaultShell = "kuma.settings.defaultShell"
        public static let customKubectlPath = "kuma.settings.customKubectlPath"
        public static let customKubeconfigPath = "kuma.settings.customKubeconfigPath"
        public static let customDockerPath = "kuma.settings.customDockerPath"
        public static let customPodmanPath = "kuma.settings.customPodmanPath"
        public static let cloudflaredPath = "kuma.settings.cloudflaredPath"
        public static let customNgrokPath = "kuma.settings.customNgrokPath"
        public static let ngrokAuthToken = "kuma.settings.ngrokAuthToken"
        public static let ngrokRegion = "kuma.settings.ngrokRegion"
        public static let notifyOnCrash = "kuma.settings.notifyOnCrash"
        public static let notifySound = "kuma.settings.notifySound"
        public static let notifyOnHealthFailure = "kuma.settings.notifyOnHealthFailure"
        public static let warnOnPortCollision = "kuma.settings.warnOnPortCollision"
        public static let promptGracefulShutdown = "kuma.settings.promptGracefulShutdown"
        public static let logRetentionLimit = "kuma.settings.logRetentionLimit"
        public static let clearLogsOnSwitch = "kuma.settings.clearLogsOnSwitch"
    }

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
        self.autoResumeServices = userDefaults.object(forKey: Keys.autoResumeServices) as? Bool ?? true
        self.confirmBeforeQuit = userDefaults.object(forKey: Keys.confirmBeforeQuit) as? Bool ?? true

        let rawAppearance = userDefaults.string(forKey: Keys.appearance) ?? KumaAppearance.system.rawValue
        self.appearance = KumaAppearance(rawValue: rawAppearance) ?? .system

        self.customPathOverride = userDefaults.string(forKey: Keys.customPathOverride) ?? ""
        self.defaultShell = userDefaults.string(forKey: Keys.defaultShell) ?? "/bin/zsh"
        self.customKubectlPath = userDefaults.string(forKey: Keys.customKubectlPath) ?? ""
        self.customKubeconfigPath = userDefaults.string(forKey: Keys.customKubeconfigPath) ?? ""
        self.customDockerPath = userDefaults.string(forKey: Keys.customDockerPath) ?? ""
        self.customPodmanPath = userDefaults.string(forKey: Keys.customPodmanPath) ?? ""

        self.cloudflaredPath = userDefaults.string(forKey: Keys.cloudflaredPath) ?? ""
        self.customNgrokPath = userDefaults.string(forKey: Keys.customNgrokPath) ?? ""
        self.ngrokAuthToken = userDefaults.string(forKey: Keys.ngrokAuthToken) ?? ""
        self.ngrokRegion = userDefaults.string(forKey: Keys.ngrokRegion) ?? "auto"

        self.notifyOnCrash = userDefaults.object(forKey: Keys.notifyOnCrash) as? Bool ?? true
        self.notifySound = userDefaults.object(forKey: Keys.notifySound) as? Bool ?? true
        self.notifyOnHealthFailure = userDefaults.object(forKey: Keys.notifyOnHealthFailure) as? Bool ?? true
        self.warnOnPortCollision = userDefaults.object(forKey: Keys.warnOnPortCollision) as? Bool ?? true
        self.promptGracefulShutdown = userDefaults.object(forKey: Keys.promptGracefulShutdown) as? Bool ?? true

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
}

extension NSApplication {
    static var sharedIfRunning: NSApplication? {
        if NSApp != nil {
            return NSApp
        }
        return nil
    }
}
