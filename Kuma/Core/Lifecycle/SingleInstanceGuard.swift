import AppKit
import Foundation
import os

public enum SingleInstanceGuard {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "SingleInstanceGuard")

    /// Checks if another instance of Kuma is already running.
    /// If an existing instance is found, it brings that instance to front and returns `true`.
    @discardableResult
    @MainActor
    public static func activateExistingInstanceIfRunning() -> Bool {
        // Skip check during XCTest / Swift Testing execution
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
           NSClassFromString("XCTestCase") != nil {
            return false
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        let currentPID = ProcessInfo.processInfo.processIdentifier

        if let existingApp = runningApps.first(where: { $0.processIdentifier != currentPID }) {
            logger.info("Found running Kuma instance (PID: \(existingApp.processIdentifier)). Bringing to front.")
            existingApp.activate()
            return true
        }

        return false
    }
}
