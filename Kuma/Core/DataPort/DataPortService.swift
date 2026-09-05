import Foundation
import AppKit
import os

public nonisolated enum DataPortService {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "DataPortService")
    public static let currentVersion = 1

    public enum DataPortError: Error, LocalizedError, Sendable {
        case unsupportedFutureVersion(backupVersion: Int, currentVersion: Int)

        public var errorDescription: String? {
            switch self {
            case .unsupportedFutureVersion(let backup, let current):
                return "The backup file was created by a newer version of Kuma (Backup v\(backup), App v\(current)). Please update Kuma."
            }
        }
    }

    // MARK: - Backup Payload (100% V3 JSON Compatible)

    public struct KumaBackup: Codable, Sendable, Identifiable {
        public var id: String { "\(version)_\(exportedAt.timeIntervalSince1970)_\(workspaces.count)" }
        public let version: Int
        public let exportedAt: Date
        public let workspaces: [Workspace]
        public let workspaceImages: [String: String]? // [workspaceID: Base64PNG]
        public let groups: [ServiceGroup]?
        public let services: [ExportService]
        public let providers: [ExportProvider]
        public let portMappings: [ExportPortMapping]
        public let kubeConfigs: [ExportKubeConfig]

        public nonisolated init(
            version: Int? = nil,
            exportedAt: Date = Date(),
            workspaces: [Workspace] = [],
            workspaceImages: [String: String]? = nil,
            groups: [ServiceGroup]? = nil,
            services: [ExportService] = [],
            providers: [ExportProvider] = [],
            portMappings: [ExportPortMapping] = [],
            kubeConfigs: [ExportKubeConfig] = []
        ) {
            self.version = version ?? DataPortService.currentVersion
            self.exportedAt = exportedAt
            self.workspaces = workspaces
            self.workspaceImages = workspaceImages
            self.groups = groups
            self.services = services
            self.providers = providers
            self.portMappings = portMappings
            self.kubeConfigs = kubeConfigs
        }
    }

    public struct ExportService: Codable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let icon: String?
        public let colorHex: String?
        public let description: String?
        public let activeProviderID: UUID?
        public let workspaceID: UUID?
        public let groupIDs: [UUID]?
        public let isDisabled: Bool?
        public let isStarred: Bool?

        public nonisolated init(
            id: UUID = UUID(),
            name: String,
            icon: String? = nil,
            colorHex: String? = nil,
            description: String? = nil,
            activeProviderID: UUID? = nil,
            workspaceID: UUID? = nil,
            groupIDs: [UUID]? = nil,
            isDisabled: Bool? = false,
            isStarred: Bool? = false
        ) {
            self.id = id
            self.name = name
            self.icon = icon
            self.colorHex = colorHex
            self.description = description
            self.activeProviderID = activeProviderID
            self.workspaceID = workspaceID
            self.groupIDs = groupIDs
            self.isDisabled = isDisabled
            self.isStarred = isStarred
        }
    }

    /// Single-service complete standalone export structure (for clipboard JSON copying & sharing)
    public struct SingleServiceExport: Codable, Sendable, Identifiable {
        public let version: Int
        public let exportedAt: Date
        public let service: ExportService
        public let providers: [ExportProvider]
        public let portMappings: [ExportPortMapping]

        public var id: UUID { service.id }

        public nonisolated init(
            version: Int = DataPortService.currentVersion,
            exportedAt: Date = Date(),
            service: ExportService,
            providers: [ExportProvider],
            portMappings: [ExportPortMapping]
        ) {
            self.version = version
            self.exportedAt = exportedAt
            self.service = service
            self.providers = providers
            self.portMappings = portMappings
        }
    }

    public struct ExportProvider: Codable, Sendable, Identifiable {
        public let id: UUID
        public let serviceID: UUID
        public let type: String
        public let label: String?
        public let kubeConfigID: UUID?
        public let customKubeConfigPath: String?
        public let kubeContext: String?
        public let kubeNamespace: String?
        public let targetName: String?
        public let kubeTargetType: String?
        public let usePattern: Bool?
        public let yamlConfig: String?
        public let initialScript: String?
        public let runCommand: String?
        public let workingDirectory: String?
        public let sshHost: String?
        public let sshUser: String?
        public let sshPort: Int?
        public let sshKeyPath: String?
        public let sshPassword: String?
        public let httpCheckUrl: String?
        public let httpCheckInterval: Int?
        public let tunnelType: String?
        public let tunnelTargetUrl: String?
        public let ngrokAuthToken: String?
        public let monitorProcessName: String?
        public let monitorInterval: Int?

        public nonisolated init(
            id: UUID = UUID(),
            serviceID: UUID,
            type: String,
            label: String? = nil,
            runCommand: String? = nil,
            yamlConfig: String? = nil,
            kubeContext: String? = nil,
            kubeNamespace: String? = nil,
            targetName: String? = nil,
            kubeConfigID: UUID? = nil,
            customKubeConfigPath: String? = nil,
            kubeTargetType: String? = nil,
            usePattern: Bool? = nil,
            initialScript: String? = nil,
            workingDirectory: String? = nil,
            sshHost: String? = nil,
            sshUser: String? = nil,
            sshPort: Int? = nil,
            sshKeyPath: String? = nil,
            sshPassword: String? = nil,
            httpCheckUrl: String? = nil,
            httpCheckInterval: Int? = nil,
            tunnelType: String? = nil,
            tunnelTargetUrl: String? = nil,
            ngrokAuthToken: String? = nil,
            monitorProcessName: String? = nil,
            monitorInterval: Int? = nil
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
            self.kubeConfigID = kubeConfigID
            self.customKubeConfigPath = customKubeConfigPath
            self.kubeTargetType = kubeTargetType
            self.usePattern = usePattern
            self.initialScript = initialScript
            self.workingDirectory = workingDirectory
            self.sshHost = sshHost
            self.sshUser = sshUser
            self.sshPort = sshPort
            self.sshKeyPath = sshKeyPath
            self.sshPassword = sshPassword
            self.httpCheckUrl = httpCheckUrl
            self.httpCheckInterval = httpCheckInterval
            self.tunnelType = tunnelType
            self.tunnelTargetUrl = tunnelTargetUrl
            self.ngrokAuthToken = ngrokAuthToken
            self.monitorProcessName = monitorProcessName
            self.monitorInterval = monitorInterval
        }


        public var category: ProviderCategory {

            switch type {
            case "kube_port_forward", "kubernetes":   return .kubernetes
            case "docker":                            return .docker
            case "podman":                            return .podman
            case "shell":                             return .shell
            case "ssh":                               return .ssh
            case "http_check", "httpCheck":           return .httpCheck
            case "tunnel":                            return .tunnel
            case "process_monitor", "processMonitor": return .processMonitor
            default:                                  return .docker
            }
        }

        public var resolvedTarget: String {
            switch category {
            case .docker, .podman:
                if let yaml = yamlConfig, let image = extractComposeImage(from: yaml) {
                    return image
                }
                if let label, !label.isEmpty {
                    return label
                }
                return category.sidebarLabel

            case .kubernetes:
                let target = targetName?.trimmingCharacters(in: .whitespaces) ?? ""
                if !target.isEmpty {
                    return target
                }
                return category.sidebarLabel

            case .shell:
                if let cmd = runCommand, !cmd.trimmingCharacters(in: .whitespaces).isEmpty {
                    return cmd.trimmingCharacters(in: .whitespaces)
                }
                return category.sidebarLabel

            case .ssh:
                if let label, !label.trimmingCharacters(in: .whitespaces).isEmpty {
                    return label.trimmingCharacters(in: .whitespaces)
                }
                let host = sshHost?.trimmingCharacters(in: .whitespaces) ?? ""
                if !host.isEmpty {
                    return host
                }
                return category.sidebarLabel

            case .httpCheck:
                if let url = httpCheckUrl, !url.trimmingCharacters(in: .whitespaces).isEmpty {
                    return url.trimmingCharacters(in: .whitespaces)
                }
                return category.sidebarLabel

            case .tunnel:
                if let target = tunnelTargetUrl, !target.trimmingCharacters(in: .whitespaces).isEmpty {
                    return target.trimmingCharacters(in: .whitespaces)
                }
                return category.sidebarLabel

            case .processMonitor:
                if let proc = monitorProcessName, !proc.trimmingCharacters(in: .whitespaces).isEmpty {
                    return proc.trimmingCharacters(in: .whitespaces)
                }
                return category.sidebarLabel
            }
        }

        private func extractComposeImage(from yaml: String) -> String? {
            let lines = yaml.components(separatedBy: .newlines)
            for rawLine in lines {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("image:") {
                    let rawImage = line.dropFirst("image:".count).trimmingCharacters(in: .whitespaces)
                    var cleaned = rawImage.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if cleaned.hasPrefix("docker.io/library/") {
                        cleaned = String(cleaned.dropFirst("docker.io/library/".count))
                    } else if cleaned.hasPrefix("docker.io/") {
                        cleaned = String(cleaned.dropFirst("docker.io/".count))
                    } else if cleaned.hasPrefix("library/") {
                        cleaned = String(cleaned.dropFirst("library/".count))
                    }
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }
            }
            return nil
        }
    }

    public struct ExportPortMapping: Codable, Sendable, Identifiable {
        public let id: UUID
        public let providerID: UUID
        public let localPort: Int
        public let remotePort: Int

        public nonisolated init(id: UUID = UUID(), providerID: UUID, localPort: Int, remotePort: Int) {
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

        public nonisolated init(id: UUID = UUID(), name: String? = nil, path: String? = nil) {
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

    public static func encodeSingleService(_ item: SingleServiceExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(item)
    }

    public static func decodeSingleService(from data: Data) throws -> SingleServiceExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SingleServiceExport.self, from: data)
    }

    /// Standardized ISO formatted date suffix for backup filenames (e.g. "2026-08-15")
    public static var backupDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Factory Reset & Relaunch

    public static func resetAllAppStorage() async {
        // 0. Terminate all running service processes / tunnels cleanly
        await ProcessRegistry.shared.terminateAll()

        // 1. Wipe UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // 2. Wipe SQLite DB
        try? AppDatabase.shared.wipeAndResetDatabase()

        // 3. Clear Local Workspace Images
        WorkspaceImageStore.shared.clearCache()
        let imagesDir = WorkspaceImageStore.shared.imagesDirectoryURL()
        try? FileManager.default.removeItem(at: imagesDir)

        logger.info("Cleared all user defaults, SQLite database records, and workspace images")
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
        } catch {
            // Fallback to NSWorkspace if process spawning fails
            let url = URL(fileURLWithPath: bundlePath)
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                Task { @MainActor in
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

