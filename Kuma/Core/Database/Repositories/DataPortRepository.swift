import Foundation
import GRDB
import os

public protocol DataPortRepositoryProtocol: Sendable {
    func exportAll() async throws -> DataPortService.KumaBackup
    func importAll(from backup: DataPortService.KumaBackup) async throws
}

/// `@unchecked Sendable`: Thread safety is guaranteed by GRDB's underlying `DatabaseWriter` (DatabasePool / DatabaseQueue)
/// which synchronizes access via serialized dispatch queues. Do not add mutable stored properties to this class.
public final class DataPortRepository: DataPortRepositoryProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "lokastudio.kuma", category: "DataPortRepository")
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
                    isDisabled: s.isDisabled,
                    isStarred: s.isStarred
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
                // In V3 JSON, providerID in portMappings maps to the service's active provider
                var associatedProviderID = pm.serviceID ?? pm.id
                if let sID = pm.serviceID {
                    if let service = services.first(where: { $0.id == sID }),
                       let activePID = service.activeProviderID {
                        associatedProviderID = activePID
                    } else if let firstProv = providers.first(where: { $0.serviceID == sID }) {
                        associatedProviderID = firstProv.id
                    }
                }

                return DataPortService.ExportPortMapping(
                    id: pm.id,
                    providerID: associatedProviderID,
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
                    isDisabled: exportService.isDisabled ?? false,
                    isStarred: exportService.isStarred ?? false
                )
                try service.save(db)
            }

            // Map & Restore Providers — handle V3 legacy type strings and complete provider fields
            for exportProvider in backup.providers {
                let providerType = exportProvider.category

                let provider = Provider(
                    id: exportProvider.id,
                    serviceID: exportProvider.serviceID,
                    type: providerType,
                    label: exportProvider.label,
                    kubeConfigID: exportProvider.kubeConfigID,
                    customKubeConfigPath: exportProvider.customKubeConfigPath,
                    kubeContext: exportProvider.kubeContext,
                    kubeNamespace: exportProvider.kubeNamespace,
                    targetName: exportProvider.targetName,
                    kubeTargetType: exportProvider.kubeTargetType,
                    usePattern: exportProvider.usePattern,
                    yamlConfig: exportProvider.yamlConfig,
                    initialScript: exportProvider.initialScript,
                    runCommand: exportProvider.runCommand,
                    workingDirectory: exportProvider.workingDirectory,
                    sshHost: exportProvider.sshHost,
                    sshUser: exportProvider.sshUser,
                    sshPort: exportProvider.sshPort,
                    sshKeyPath: exportProvider.sshKeyPath,
                    sshPassword: exportProvider.sshPassword,
                    httpCheckUrl: exportProvider.httpCheckUrl,
                    httpCheckInterval: exportProvider.httpCheckInterval,
                    tunnelType: exportProvider.tunnelType,
                    tunnelTargetUrl: exportProvider.tunnelTargetUrl,
                    ngrokAuthToken: exportProvider.ngrokAuthToken,
                    monitorProcessName: exportProvider.monitorProcessName,
                    monitorInterval: exportProvider.monitorInterval
                )
                try provider.save(db)
            }

            // Map & Restore Port Mappings (O(1) In-Memory Lookup, Zero N+1 DB roundtrips)
            let providerToServiceMap = Dictionary(uniqueKeysWithValues: backup.providers.map { ($0.id, $0.serviceID) })
            let serviceIdSet = Set(backup.services.map(\.id))

            for exportPort in backup.portMappings {
                var targetServiceID: UUID? = nil
                if let mappedSID = providerToServiceMap[exportPort.providerID] {
                    targetServiceID = mappedSID
                } else if serviceIdSet.contains(exportPort.providerID) {
                    targetServiceID = exportPort.providerID
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

    /// Selectively restores chosen workspaces and services into SQLite.
    public func importSelective(
        from backup: DataPortService.KumaBackup,
        selectedWorkspaceIDs: Set<UUID>,
        selectedServiceIDs: Set<UUID>
    ) async throws {
        let filteredWorkspaces = backup.workspaces.filter { selectedWorkspaceIDs.contains($0.id) }
        let filteredServices = backup.services.filter { selectedServiceIDs.contains($0.id) }
        let filteredServiceIdSet = Set(filteredServices.map(\.id))
        let filteredProviders = backup.providers.filter { filteredServiceIdSet.contains($0.serviceID) }
        let filteredProviderIdSet = Set(filteredProviders.map(\.id))
        let filteredPortMappings = backup.portMappings.filter {
            filteredProviderIdSet.contains($0.providerID) || filteredServiceIdSet.contains($0.providerID)
        }

        let filteredBackup = DataPortService.KumaBackup(
            version: backup.version,
            exportedAt: backup.exportedAt,
            workspaces: filteredWorkspaces,
            workspaceImages: backup.workspaceImages,
            services: filteredServices,
            providers: filteredProviders,
            portMappings: filteredPortMappings,
            kubeConfigs: []
        )

        try await importAll(from: filteredBackup)
    }

    /// Exports only data belonging to a single workspace.
    public func exportWorkspace(id: UUID) async throws -> DataPortService.KumaBackup {
        let (workspaces, exportServices, exportProviders, exportPortMappings) = try await dbWriter.read { db in
            let workspaces = try Workspace.filter(Column("id") == id.uuidString).fetchAll(db)
            let services = try Service.filter(Column("workspaceID") == id.uuidString).order(Column("createdAt").asc).fetchAll(db)
            let serviceIDs = Set(services.map(\.id))
            let allProviders = try Provider.order(Column("createdAt").asc).fetchAll(db)
            let providers = allProviders.filter { serviceIDs.contains($0.serviceID) }
            let allPortMappings = try ServicePortMapping.fetchAll(db)
            let portMappings = allPortMappings.filter { pm in
                if let sID = pm.serviceID, serviceIDs.contains(sID) { return true }
                return false
            }

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
                var associatedProviderID = pm.serviceID ?? pm.id
                if let sID = pm.serviceID {
                    if let service = services.first(where: { $0.id == sID }),
                       let activePID = service.activeProviderID {
                        associatedProviderID = activePID
                    } else if let firstProv = providers.first(where: { $0.serviceID == sID }) {
                        associatedProviderID = firstProv.id
                    }
                }

                return DataPortService.ExportPortMapping(
                    id: pm.id,
                    providerID: associatedProviderID,
                    localPort: pm.localPort,
                    remotePort: pm.remotePort
                )
            }

            return (workspaces, exportServices, exportProviders, exportPortMappings)
        }

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

    /// Selectively imports services directly into a target workspace (generating new UUIDs to prevent ID collision/stealing).
    /// Supports custom resolved names (e.g. for avoiding duplicate name collisions).
    public func importIntoWorkspace(
        targetWorkspaceID: UUID,
        backup: DataPortService.KumaBackup,
        selectedServiceIDs: Set<UUID>,
        resolvedNames: [UUID: String] = [:]
    ) async throws {
        // 1. Create ID mapping from old service ID -> new service ID
        var serviceIDMap: [UUID: UUID] = [:]
        var providerIDMap: [UUID: UUID] = [:]

        let chosenExportServices = backup.services.filter { selectedServiceIDs.contains($0.id) }
        for s in chosenExportServices {
            serviceIDMap[s.id] = UUID()
        }

        let newServices = chosenExportServices.map { s in
            let finalName = resolvedNames[s.id] ?? s.name
            return DataPortService.ExportService(
                id: serviceIDMap[s.id] ?? UUID(),
                name: finalName,
                description: s.description,
                workspaceID: targetWorkspaceID,
                isDisabled: s.isDisabled
            )
        }


        // 2. Map and re-ID Providers
        let oldServiceIdSet = Set(chosenExportServices.map(\.id))
        let chosenExportProviders = backup.providers.filter { oldServiceIdSet.contains($0.serviceID) }
        for p in chosenExportProviders {
            providerIDMap[p.id] = UUID()
        }

        let newProviders = chosenExportProviders.map { p in
            DataPortService.ExportProvider(
                id: providerIDMap[p.id] ?? UUID(),
                serviceID: serviceIDMap[p.serviceID] ?? p.serviceID,
                type: p.type,
                label: p.label,
                runCommand: p.runCommand,
                yamlConfig: p.yamlConfig,
                kubeContext: p.kubeContext,
                kubeNamespace: p.kubeNamespace,
                targetName: p.targetName
            )
        }

        // 3. Map and re-ID Port Mappings
        let oldProviderIdSet = Set(chosenExportProviders.map(\.id))
        let chosenExportPortMappings = backup.portMappings.filter {
            oldProviderIdSet.contains($0.providerID) || oldServiceIdSet.contains($0.providerID)
        }

        let newPortMappings = chosenExportPortMappings.map { pm in
            let newProvID: UUID
            if let mappedPID = providerIDMap[pm.providerID] {
                newProvID = mappedPID
            } else if let mappedSID = serviceIDMap[pm.providerID] {
                newProvID = mappedSID
            } else {
                newProvID = pm.providerID
            }

            return DataPortService.ExportPortMapping(
                id: UUID(),
                providerID: newProvID,
                localPort: pm.localPort,
                remotePort: pm.remotePort
            )
        }

        let newBackup = DataPortService.KumaBackup(
            version: backup.version,
            exportedAt: backup.exportedAt,
            workspaces: [],
            workspaceImages: nil,
            services: newServices,
            providers: newProviders,
            portMappings: newPortMappings,
            kubeConfigs: []
        )

        try await importAll(from: newBackup)
    }
}
