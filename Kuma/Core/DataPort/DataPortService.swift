//
//  DataPortService.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% Compatible with Kuma V3 JSON Backup Payload.
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import os

public enum DataPortService {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "DataPortService")
    public static let currentVersion = 1

    public enum DataPortError: LocalizedError {
        case unsupportedFutureVersion(backupVersion: Int, currentVersion: Int)
        case invalidData
        case exportCancelled
        case importCancelled

        public var errorDescription: String? {
            switch self {
            case .unsupportedFutureVersion(let backup, let current):
                return "The backup file was created by a newer version of Kuma (Backup v\(backup), App v\(current)). Please update Kuma."
            case .invalidData:
                return "The backup file format is corrupted or invalid JSON."
            case .exportCancelled, .importCancelled:
                return "Operation was cancelled."
            }
        }
    }

    // MARK: - Backup Payload (100% V3 JSON Compatible)

    public struct KumaBackup: Codable, Sendable {
        public let version: Int
        public let exportedAt: Date
        public let workspaces: [Workspace]
        public let services: [ExportService]
        public let providers: [ExportProvider]
        public let portMappings: [ExportPortMapping]
        public let kubeConfigs: [ExportKubeConfig]

        public init(
            version: Int = DataPortService.currentVersion,
            exportedAt: Date = Date(),
            workspaces: [Workspace] = [],
            services: [ExportService] = [],
            providers: [ExportProvider] = [],
            portMappings: [ExportPortMapping] = [],
            kubeConfigs: [ExportKubeConfig] = []
        ) {
            self.version = version
            self.exportedAt = exportedAt
            self.workspaces = workspaces
            self.services = services
            self.providers = providers
            self.portMappings = portMappings
            self.kubeConfigs = kubeConfigs
        }
    }

    // Flexible models supporting V3 JSON structure
    public struct ExportService: Codable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let description: String?
        public let workspaceID: UUID?
        public let isDisabled: Bool?

        public init(id: UUID = UUID(), name: String, description: String? = nil, workspaceID: UUID? = nil, isDisabled: Bool? = false) {
            self.id = id
            self.name = name
            self.description = description
            self.workspaceID = workspaceID
            self.isDisabled = isDisabled
        }
    }

    public struct ExportProvider: Codable, Sendable, Identifiable {
        public let id: UUID
        public let serviceID: UUID
        public let type: String
        public let label: String?
        public let runCommand: String?
        public let yamlConfig: String?
        public let kubeContext: String?
        public let kubeNamespace: String?
        public let targetName: String?

        public init(
            id: UUID = UUID(),
            serviceID: UUID,
            type: String,
            label: String? = nil,
            runCommand: String? = nil,
            yamlConfig: String? = nil,
            kubeContext: String? = nil,
            kubeNamespace: String? = nil,
            targetName: String? = nil
        ) {
            self.id = id
            self.serviceID = serviceID
            self.type = type
            self.label = label
            self.runCommand = runCommand
            self.yamlConfig = yamlConfig
            self.kubeContext = kubeContext
            self.kubeNamespace = kubeNamespace
            self.targetName = targetName
        }
    }

    public struct ExportPortMapping: Codable, Sendable, Identifiable {
        public let id: UUID
        public let providerID: UUID
        public let localPort: Int
        public let remotePort: Int

        public init(id: UUID = UUID(), providerID: UUID, localPort: Int, remotePort: Int) {
            self.id = id
            self.providerID = providerID
            self.localPort = localPort
            self.remotePort = remotePort
        }
    }

    public struct ExportKubeConfig: Codable, Sendable, Identifiable {
        public let id: UUID
        public let name: String?
        public let path: String?

        public init(id: UUID = UUID(), name: String? = nil, path: String? = nil) {
            self.id = id
            self.name = name
            self.path = path
        }
    }

    // MARK: - Export & Import Engine

    public static func encodeBackup(_ backup: KumaBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    public static func decodeBackup(from data: Data) throws -> KumaBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(KumaBackup.self, from: data)

        guard backup.version <= currentVersion else {
            throw DataPortError.unsupportedFutureVersion(backupVersion: backup.version, currentVersion: currentVersion)
        }

        return backup
    }

    @MainActor
    public static func promptExport(backup: KumaBackup) async throws -> URL {
        let panel = NSSavePanel()
        panel.title = "Export Kuma Configuration Backup"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "kuma-backup-\(formatter.string(from: Date())).json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            throw DataPortError.exportCancelled
        }

        let data = try encodeBackup(backup)
        try data.write(to: url)
        logger.info("Backup successfully exported to \(url.path)")
        return url
    }

    @MainActor
    public static func promptImport() async throws -> KumaBackup {
        let panel = NSOpenPanel()
        panel.title = "Import Kuma Configuration Backup"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            throw DataPortError.importCancelled
        }

        let data = try Data(contentsOf: url)
        return try decodeBackup(from: data)
    }

    // MARK: - Factory Reset & Relaunch

    public static func resetAllUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
        logger.info("Cleared all user defaults storage")
    }

    @MainActor
    public static func relaunchApp() {
        let bundlePath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; open \"\(bundlePath)\""
        ]

        do {
            try process.run()
            NSApp.terminate(nil)
            exit(0)
        } catch {
            // Fallback to NSWorkspace if process spawning fails
            let url = URL(fileURLWithPath: bundlePath)
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
