import Foundation
import GRDB
import os

public protocol DataPortRepositoryProtocol: Sendable {
    func exportData(scope: DataPortService.DataPortScope) async throws -> DataPortService.KumaBackup
    func importData(backup: DataPortService.KumaBackup, strategy: DataPortService.DataPortImportStrategy) async throws
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

    // MARK: - Unified Scoped Operations

    /// Unified export operation scoped to all, single workspace, or single service.
    public func exportData(scope: DataPortService.DataPortScope) async throws -> DataPortService.KumaBackup {
        switch scope {
        case .all:
            return try await exportAll()
        case .workspace(let wsID):
            return try await exportWorkspace(id: wsID)
        case .service(let serviceID):
            return try await exportSingleServiceBackup(serviceID: serviceID)
        }
    }

    /// Unified import operation applying either preserveOrMerge or reassignIDs strategy.
    public func importData(backup: DataPortService.KumaBackup, strategy: DataPortService.DataPortImportStrategy) async throws {
        switch strategy {
        case .preserveOrMerge:
            try await importAll(from: backup)
        case .reassignIDs(let targetWSID):
            let allServiceIDs = Set(backup.services.map(\.id))
            try await importIntoWorkspace(targetWorkspaceID: targetWSID, backup: backup, selectedServiceIDs: allServiceIDs)
        }
    }

    private func exportSingleServiceBackup(serviceID: UUID) async throws -> DataPortService.KumaBackup {
        let (service, providers, ports) = try await dbWriter.read { db -> (Service?, [Provider], [ServicePortMapping]) in
            let svc = try Service.fetchOne(db, key: serviceID.uuidString)
            let provs = try Provider.filter(Column("serviceID") == serviceID.uuidString).fetchAll(db)
            let portMaps = try ServicePortMapping.filter(Column("serviceID") == serviceID.uuidString).fetchAll(db)
            return (svc, provs, portMaps)
        }

        guard let svc = service else {
            throw NSError(domain: "lokastudio.kuma.dataport", code: 404, userInfo: [NSLocalizedDescriptionKey: "Service \(serviceID) not found."])
        }

        let exportService = DataPortService.ExportService(
            id: svc.id,
            name: svc.name,
            icon: svc.icon,
            colorHex: svc.colorHex,
            description: svc.description,
            activeProviderID: svc.activeProviderID,
            workspaceID: svc.workspaceID,
            groupIDs: Array(svc.groupIDs),
            isDisabled: svc.isDisabled,
            isStarred: svc.isStarred
        )

        let exportProviders = providers.map { Self.toExportProvider($0) }
        let exportPorts = ports.map { p in
            DataPortService.ExportPortMapping(
                id: p.id,
                providerID: svc.activeProviderID ?? svc.id,
                localPort: p.localPort,
                remotePort: p.remotePort
            )
        }

        return DataPortService.KumaBackup(
            version: DataPortService.currentVersion,
            exportedAt: Date(),
            workspaces: [],
            workspaceImages: nil,
            groups: nil,
            services: [exportService],
            providers: exportProviders,
            portMappings: exportPorts,
            kubeConfigs: []
        )
    }

    /// Exports full relational data from SQLite into KumaBackup payload.
    /// Image I/O is done outside the DB read closure to keep transaction short.
    public func exportAll() async throws -> DataPortService.KumaBackup {
        // 1. Read relational data inside a single DB read transaction
        let (workspaces, exportGroups, exportServices, exportProviders, exportPortMappings) = try await dbWriter.read { db in
            let workspaces = try Workspace.order(Column("sortOrder").asc, Column("createdAt").asc).fetchAll(db)
            let groups = try ServiceGroup.order(Column("sortOrder").asc, Column("createdAt").asc).fetchAll(db)
            let services = try Service.order(Column("createdAt").asc).fetchAll(db)
            let providers = try Provider.order(Column("createdAt").asc).fetchAll(db)
            let portMappings = try ServicePortMapping.fetchAll(db)
            let memberships = try ServiceGroupMembershipRecord.fetchAll(db)

            var groupsByServiceID: [UUID: [UUID]] = [:]
            for m in memberships {
                groupsByServiceID[m.serviceID, default: []].append(m.groupID)
            }

            let exportServices = services.map { s in
                DataPortService.ExportService(
                    id: s.id,
                    name: s.name,
                    icon: s.icon,
                    colorHex: s.colorHex,
                    description: s.description,
                    activeProviderID: s.activeProviderID,
                    workspaceID: s.workspaceID,
                    groupIDs: groupsByServiceID[s.id],
                    isDisabled: s.isDisabled,
                    isStarred: s.isStarred
                )
            }

            let exportProviders = providers.map { p in
                Self.toExportProvider(p)
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

            return (workspaces, groups, exportServices, exportProviders, exportPortMappings)
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
            groups: exportGroups,
            services: exportServices,
            providers: exportProviders,
            portMappings: exportPortMappings,
            kubeConfigs: []
        )
    }

    /// Restores full relational data into SQLite (Workspaces, Groups, Services, Providers, PortMappings).
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

            // Restore Groups if present
            if let groups = backup.groups {
                for group in groups {
                    try group.save(db)
                }
            }

            // Map & Restore Services
            for exportService in backup.services {
                let service = Service(
                    id: exportService.id,
                    name: exportService.name,
                    icon: exportService.icon,
                    colorHex: exportService.colorHex,
                    description: exportService.description,
                    activeProviderID: exportService.activeProviderID,
                    workspaceID: exportService.workspaceID,
                    groupIDs: Set(exportService.groupIDs ?? []),
                    isDisabled: exportService.isDisabled ?? false,
                    isStarred: exportService.isStarred ?? false
                )
                try service.save(db)

                // Restore group memberships
                if let gIDs = exportService.groupIDs {
                    for gID in gIDs {
                        let membership = ServiceGroupMembershipRecord(serviceID: service.id, groupID: gID)
                        try membership.save(db)
                    }
                }
            }

            // Map & Restore Providers — 100% full fields preservation
            for exportProvider in backup.providers {
                let provider = Self.fromExportProvider(exportProvider)
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
            groups: backup.groups?.filter { g in
                if let wsID = g.workspaceID { return selectedWorkspaceIDs.contains(wsID) }
                return true
            },
            services: filteredServices,
            providers: filteredProviders,
            portMappings: filteredPortMappings,
            kubeConfigs: []
        )

        try await importAll(from: filteredBackup)
    }

    /// Exports only data belonging to a single workspace.
    public func exportWorkspace(id: UUID) async throws -> DataPortService.KumaBackup {
        let (workspaces, groups, exportServices, exportProviders, exportPortMappings) = try await dbWriter.read { db in
            let workspaces = try Workspace.filter(Column("id") == id.uuidString).fetchAll(db)
            let groups = try ServiceGroup.filter(Column("workspaceID") == id.uuidString).order(Column("sortOrder").asc).fetchAll(db)
            let services = try Service.filter(Column("workspaceID") == id.uuidString).order(Column("createdAt").asc).fetchAll(db)
            let serviceIDStrings = services.map { $0.id.uuidString }
            let serviceIDs = Set(services.map(\.id))

            let providers: [Provider]
            let portMappings: [ServicePortMapping]
            let memberships: [ServiceGroupMembershipRecord]

            if !serviceIDStrings.isEmpty {
                providers = try Provider
                    .filter(serviceIDStrings.contains(Column("serviceID")))
                    .order(Column("createdAt").asc)
                    .fetchAll(db)
                portMappings = try ServicePortMapping
                    .filter(serviceIDStrings.contains(Column("serviceID")))
                    .fetchAll(db)
                memberships = try ServiceGroupMembershipRecord
                    .filter(serviceIDStrings.contains(Column("serviceID")))
                    .fetchAll(db)
            } else {
                providers = []
                portMappings = []
                memberships = []
            }

            var groupsByServiceID: [UUID: [UUID]] = [:]
            for m in memberships {
                groupsByServiceID[m.serviceID, default: []].append(m.groupID)
            }

            let exportServices = services.map { s in
                DataPortService.ExportService(
                    id: s.id,
                    name: s.name,
                    icon: s.icon,
                    colorHex: s.colorHex,
                    description: s.description,
                    activeProviderID: s.activeProviderID,
                    workspaceID: s.workspaceID,
                    groupIDs: groupsByServiceID[s.id],
                    isDisabled: s.isDisabled,
                    isStarred: s.isStarred
                )
            }

            let exportProviders = providers.map { p in
                Self.toExportProvider(p)
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

            return (workspaces, groups, exportServices, exportProviders, exportPortMappings)
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
            groups: groups,
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
        var serviceIDMap: [UUID: UUID] = [:]
        var providerIDMap: [UUID: UUID] = [:]

        let chosenExportServices = backup.services.filter { selectedServiceIDs.contains($0.id) }
        for s in chosenExportServices {
            serviceIDMap[s.id] = UUID()
        }

        let newServices = chosenExportServices.map { s in
            let finalName = resolvedNames[s.id] ?? s.name
            let mappedActiveProvID = s.activeProviderID.flatMap { providerIDMap[$0] }
            return DataPortService.ExportService(
                id: serviceIDMap[s.id] ?? UUID(),
                name: finalName,
                icon: s.icon,
                colorHex: s.colorHex,
                description: s.description,
                activeProviderID: mappedActiveProvID,
                workspaceID: targetWorkspaceID,
                groupIDs: s.groupIDs,
                isDisabled: s.isDisabled,
                isStarred: s.isStarred
            )
        }

        // Map and re-ID Providers
        let oldServiceIdSet = Set(chosenExportServices.map(\.id))
        let chosenExportProviders = backup.providers.filter { oldServiceIdSet.contains($0.serviceID) }
        for p in chosenExportProviders {
            providerIDMap[p.id] = UUID()
        }

        let newProviders = chosenExportProviders.map { p in
            var updated = p
            return DataPortService.ExportProvider(
                id: providerIDMap[p.id] ?? UUID(),
                serviceID: serviceIDMap[p.serviceID] ?? p.serviceID,
                type: p.type,
                label: p.label,
                runCommand: p.runCommand,
                yamlConfig: p.yamlConfig,
                kubeContext: p.kubeContext,
                kubeNamespace: p.kubeNamespace,
                targetName: p.targetName,
                kubeConfigID: p.kubeConfigID,
                customKubeConfigPath: p.customKubeConfigPath,
                kubeTargetType: p.kubeTargetType,
                usePattern: p.usePattern,
                initialScript: p.initialScript,
                workingDirectory: p.workingDirectory,
                sshHost: p.sshHost,
                sshUser: p.sshUser,
                sshPort: p.sshPort,
                sshKeyPath: p.sshKeyPath,
                sshPassword: p.sshPassword,
                httpCheckUrl: p.httpCheckUrl,
                httpCheckInterval: p.httpCheckInterval,
                tunnelType: p.tunnelType,
                tunnelTargetUrl: p.tunnelTargetUrl,
                ngrokAuthToken: p.ngrokAuthToken,
                monitorProcessName: p.monitorProcessName,
                monitorInterval: p.monitorInterval
            )
        }

        // Map and re-ID Port Mappings
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
            groups: backup.groups,
            services: newServices,
            providers: newProviders,
            portMappings: newPortMappings,
            kubeConfigs: []
        )

        try await importAll(from: newBackup)
    }

    // MARK: - Helpers

    public static func toExportProvider(_ p: Provider) -> DataPortService.ExportProvider {
        let encryptedPassword: String?
        if let pass = p.sshPassword, !pass.isEmpty {
            encryptedPassword = (try? CryptoVault.shared.encrypt(plainText: pass)) ?? pass
        } else {
            encryptedPassword = nil
        }

        let encryptedToken: String?
        if let token = p.ngrokAuthToken, !token.isEmpty {
            encryptedToken = (try? CryptoVault.shared.encrypt(plainText: token)) ?? token
        } else {
            encryptedToken = nil
        }

        return DataPortService.ExportProvider(
            id: p.id,
            serviceID: p.serviceID,
            type: p.type.rawValue,
            label: p.label,
            runCommand: p.runCommand,
            yamlConfig: p.yamlConfig,
            kubeContext: p.kubeContext,
            kubeNamespace: p.kubeNamespace,
            targetName: p.targetName,
            kubeConfigID: p.kubeConfigID,
            customKubeConfigPath: p.customKubeConfigPath,
            kubeTargetType: p.kubeTargetType,
            usePattern: p.usePattern,
            initialScript: p.initialScript,
            workingDirectory: p.workingDirectory,
            sshHost: p.sshHost,
            sshUser: p.sshUser,
            sshPort: p.sshPort,
            sshKeyPath: p.sshKeyPath,
            sshPassword: encryptedPassword,
            httpCheckUrl: p.httpCheckUrl,
            httpCheckInterval: p.httpCheckInterval,
            tunnelType: p.tunnelType,
            tunnelTargetUrl: p.tunnelTargetUrl,
            ngrokAuthToken: encryptedToken,
            monitorProcessName: p.monitorProcessName,
            monitorInterval: p.monitorInterval
        )
    }

    public static func fromExportProvider(_ p: DataPortService.ExportProvider) -> Provider {
        let decryptedPassword: String?
        if let pass = p.sshPassword, !pass.isEmpty {
            decryptedPassword = (try? CryptoVault.shared.decrypt(cipherText: pass)) ?? pass
        } else {
            decryptedPassword = nil
        }

        let decryptedToken: String?
        if let token = p.ngrokAuthToken, !token.isEmpty {
            decryptedToken = (try? CryptoVault.shared.decrypt(cipherText: token)) ?? token
        } else {
            decryptedToken = nil
        }

        return Provider(
            id: p.id,
            serviceID: p.serviceID,
            type: p.category,
            label: p.label,
            kubeConfigID: p.kubeConfigID,
            customKubeConfigPath: p.customKubeConfigPath,
            kubeContext: p.kubeContext,
            kubeNamespace: p.kubeNamespace,
            targetName: p.targetName,
            kubeTargetType: p.kubeTargetType,
            usePattern: p.usePattern,
            yamlConfig: p.yamlConfig,
            initialScript: p.initialScript,
            runCommand: p.runCommand,
            workingDirectory: p.workingDirectory,
            sshHost: p.sshHost,
            sshUser: p.sshUser,
            sshPort: p.sshPort,
            sshKeyPath: p.sshKeyPath,
            sshPassword: decryptedPassword,
            httpCheckUrl: p.httpCheckUrl,
            httpCheckInterval: p.httpCheckInterval,
            tunnelType: p.tunnelType,
            tunnelTargetUrl: p.tunnelTargetUrl,
            ngrokAuthToken: decryptedToken,
            monitorProcessName: p.monitorProcessName,
            monitorInterval: p.monitorInterval
        )
    }

    /// Exports a single service along with its providers and port mappings as formatted JSON string.
    public func exportSingleServiceJSON(serviceID: UUID) async throws -> String {
        let (service, providers, ports) = try await dbWriter.read { db -> (Service?, [Provider], [ServicePortMapping]) in
            let svc = try Service.fetchOne(db, key: serviceID.uuidString)
            let provs = try Provider.filter(Column("serviceID") == serviceID.uuidString).fetchAll(db)
            let portMaps = try ServicePortMapping.filter(Column("serviceID") == serviceID.uuidString).fetchAll(db)
            return (svc, provs, portMaps)
        }

        guard let svc = service else {
            throw NSError(domain: "lokastudio.kuma.dataport", code: 404, userInfo: [NSLocalizedDescriptionKey: "Service \(serviceID) not found."])
        }

        let exportService = DataPortService.ExportService(
            id: svc.id,
            name: svc.name,
            icon: svc.icon,
            colorHex: svc.colorHex,
            description: svc.description,
            activeProviderID: svc.activeProviderID,
            workspaceID: svc.workspaceID,
            groupIDs: Array(svc.groupIDs),
            isDisabled: svc.isDisabled,
            isStarred: svc.isStarred
        )

        let exportProviders = providers.map { Self.toExportProvider($0) }
        let exportPorts = ports.map { p in
            DataPortService.ExportPortMapping(
                id: p.id,
                providerID: svc.activeProviderID ?? svc.id,
                localPort: p.localPort,
                remotePort: p.remotePort
            )
        }

        let singleExport = DataPortService.SingleServiceExport(
            version: DataPortService.currentVersion,
            exportedAt: Date(),
            service: exportService,
            providers: exportProviders,
            portMappings: exportPorts
        )

        let data = try DataPortService.encodeSingleService(singleExport)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "lokastudio.kuma.dataport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to encode service JSON."])
        }
        return jsonString
    }
}
