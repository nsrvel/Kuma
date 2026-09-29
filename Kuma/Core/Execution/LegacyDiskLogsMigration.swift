import Foundation

enum LegacyDiskLogsMigration {
    nonisolated static func purgeIfNeeded() {
        let migrationKey = "kuma.migration.legacyDiskLogsRemoved"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let logsDir = support.appendingPathComponent("Kuma/Logs", isDirectory: true)
        if FileManager.default.fileExists(atPath: logsDir.path) {
            try? FileManager.default.removeItem(at: logsDir)
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
