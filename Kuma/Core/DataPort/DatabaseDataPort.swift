import Foundation
import GRDB
import os

public protocol DataPortImportExportProtocol: Sendable {
    func exportAll() async throws -> DataPortService.KumaBackup
    func importAll(from backup: DataPortService.KumaBackup) async throws
}

public final class DatabaseDataPort: DataPortImportExportProtocol {
    private let logger = Logger(subsystem: "lokastudio.kuma", category: "DatabaseDataPort")
    private let dbWriter: any DatabaseWriter

    public nonisolated init(dbWriter: (any DatabaseWriter)? = nil) {
        self.dbWriter = dbWriter ?? AppDatabase.shared.dbWriter
    }

    /// Exports full relational data from SQLite into KumaBackup payload.
    /// Image I/O is done outside the DB read closure to keep transaction short.
    public func exportAll() async throws -> DataPortService.KumaBackup {
        // 1. Read relational data inside a single DB read transaction
        let (workspaces, exportServices, exportProviders, exportPortMappings) = try await dbWriter.read { db in
            let workspaces = try Workspace.order(Column("sortOrder").asc, Column("createdAt").asc).fetchAll(db)
            let services = try Service.order(Column("createdAt").asc).fetchAll(db)
            let providers = try Provider.order(Column("createdAt").asc).fetchAll(db)
            let portMappings = try ServicePortMapping.fetchAll(db)

            let exportServices = services.map { s in
                DataPortService.ExportService(
                    id: s.id,
                    name: s.name,
                    description: s.description,
                    workspaceID: s.workspaceID,
                    isDisabled: s.isDisabled
                )
            }

            let exportProviders = providers.map { p in
                DataPortService.ExportProvider(
                    id: p.id,
                    serviceID: p.serviceID,
                    type: p.type.rawValue,
                    label: p.label,
                    runCommand: p.runCommand,
                    yamlConfig: p.yamlConfig,
                    kubeContext: p.kubeContext,
                    kubeNamespace: p.kubeNamespace,
                    targetName: p.targetName
                )
            }

            let exportPortMappings = portMappings.map { pm in
                DataPortService.ExportPortMapping(
                    id: pm.id,
                    providerID: pm.id,
                    localPort: pm.localPort,
                    remotePort: pm.remotePort
                )
            }

            return (workspaces, exportServices, exportProviders, exportPortMappings)
        }

        // 2. Load Base64 images outside DB closure (pure disk I/O, no transaction held)
        var imagesMap: [String: String] = [:]
        for ws in workspaces {
            if let imagePath = ws.imagePath,
               let base64 = WorkspaceImageStore.shared.loadBase64Image(for: imagePath) {
                imagesMap[ws.id.uuidString] = base64
            }
        }

        return DataPortService.KumaBackup(
            version: DataPortService.currentVersion,
            exportedAt: Date(),
            workspaces: workspaces,
            workspaceImages: imagesMap.isEmpty ? nil : imagesMap,
            services: exportServices,
            providers: exportProviders,
            portMappings: exportPortMappings,
            kubeConfigs: []
        )
    }

    /// Restores full relational data into SQLite (Workspaces, Services, Providers, PortMappings).
    /// Image I/O is resolved before the DB write transaction to avoid holding the write lock during disk ops.
    public func importAll(from backup: DataPortService.KumaBackup) async throws {
        // 1. Resolve & save any Base64 images to disk BEFORE opening DB write transaction
        var resolvedImagePaths: [UUID: String] = [:]
        if let imagesMap = backup.workspaceImages {
            for ws in backup.workspaces {
                if let base64 = imagesMap[ws.id.uuidString],
                   let fileName = WorkspaceImageStore.shared.saveBase64Image(base64, workspaceID: ws.id) {
                    resolvedImagePaths[ws.id] = fileName
                }
            }
        }

        // 2. Write all relational data in a single atomic DB transaction
        let paths = resolvedImagePaths
        try await dbWriter.write { db in
            // Restore Workspaces
            for ws in backup.workspaces {
                var workspaceToSave = ws
                if let resolvedPath = paths[ws.id] {
                    workspaceToSave.imagePath = resolvedPath
                }
                try workspaceToSave.save(db)
            }

            // Map & Restore Services
            for exportService in backup.services {
                let service = Service(
                    id: exportService.id,
                    name: exportService.name,
                    description: exportService.description,
                    workspaceID: exportService.workspaceID,
                    isDisabled: exportService.isDisabled ?? false
                )
                try service.save(db)
            }

            // Map & Restore Providers — handle V3 legacy type strings
            for exportProvider in backup.providers {
                let providerType: ProviderCategory
                switch exportProvider.type {
                case "kube_port_forward", "kubernetes":   providerType = .kubernetes
                case "docker":                            providerType = .docker
                case "podman":                            providerType = .podman
                case "shell":                             providerType = .shell
                case "ssh":                               providerType = .ssh
                case "http_check", "httpCheck":           providerType = .httpCheck
                case "tunnel":                            providerType = .tunnel
                case "process_monitor", "processMonitor": providerType = .processMonitor
                default:                                  providerType = .docker
                }

                let provider = Provider(
                    id: exportProvider.id,
                    serviceID: exportProvider.serviceID,
                    type: providerType,
                    label: exportProvider.label,
                    kubeContext: exportProvider.kubeContext,
                    kubeNamespace: exportProvider.kubeNamespace,
                    targetName: exportProvider.targetName,
                    yamlConfig: exportProvider.yamlConfig,
                    runCommand: exportProvider.runCommand
                )
                try provider.save(db)
            }

            // Map & Restore Port Mappings
            // V3 portMappings used providerID; resolve to serviceID via the provider table
            for exportPort in backup.portMappings {
                var targetServiceID: UUID? = nil
                if let providerRow = try Provider.fetchOne(db, key: exportPort.providerID.uuidString) {
                    targetServiceID = providerRow.serviceID
                } else if let serviceRow = try Service.fetchOne(db, key: exportPort.providerID.uuidString) {
                    targetServiceID = serviceRow.id
                }

                if let targetServiceID {
                    try db.execute(
                        sql: """
                        INSERT INTO portMapping (id, serviceID, localPort, remotePort, protocolType)
                        VALUES (?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET localPort=excluded.localPort, remotePort=excluded.remotePort
                        """,
                        arguments: [
                            exportPort.id.uuidString,
                            targetServiceID.uuidString,
                            exportPort.localPort,
                            exportPort.remotePort,
                            "TCP"
                        ]
                    )
                }
            }

            self.logger.info("Imported backup: \(backup.workspaces.count) workspaces, \(backup.services.count) services, \(backup.providers.count) providers")
        }
    }
}
