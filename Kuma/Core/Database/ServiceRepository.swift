import Foundation
import GRDB

public protocol ServiceRepositoryProtocol: Sendable {
    func fetchSnapshots(forWorkspace workspaceID: UUID) async throws -> [ServiceCardSnapshot]
    func fetchService(id: UUID) async throws -> Service?
    func fetchProviders(forService serviceID: UUID) async throws -> [Provider]
    func fetchPortMappings(forService serviceID: UUID) async throws -> [ServicePortMapping]
    func insertService(_ service: Service, defaultProvider: Provider?, portMappings: [ServicePortMapping]) async throws
    func updateService(_ service: Service) async throws
    func toggleStarred(serviceID: UUID) async throws -> Bool
    func deleteService(id: UUID) async throws

    // Group Management
    func fetchGroups(forWorkspace workspaceID: UUID) async throws -> [ServiceGroup]
    func createGroup(workspaceID: UUID, name: String) async throws -> ServiceGroup
    func renameGroup(id: UUID, newName: String) async throws
    func deleteGroup(id: UUID) async throws
}

public final class ServiceRepository: ServiceRepositoryProtocol {
    private let dbWriter: any DatabaseWriter

    public nonisolated init(dbWriter: (any DatabaseWriter)? = nil) {
        self.dbWriter = dbWriter ?? AppDatabase.shared.dbWriter
    }

    /// High-performance projection query: Reads only necessary fields for UI list without loading entire record payload
    public func fetchSnapshots(forWorkspace workspaceID: UUID) async throws -> [ServiceCardSnapshot] {
        try await dbWriter.read { db in
            let services = try Service
                .filter(Column("workspaceID") == workspaceID.uuidString)
                .order(Column("createdAt").asc)
                .fetchAll(db)

            var snapshots: [ServiceCardSnapshot] = []
            snapshots.reserveCapacity(services.count)

            for service in services {
                var category: ProviderCategory = .docker
                var subtitle: String = service.description ?? ""

                if let activeProvID = service.activeProviderID,
                   let provider = try Provider.fetchOne(db, key: activeProvID.uuidString) {
                    category = provider.type
                    subtitle = provider.resolvedTarget
                } else if let firstProv = try Provider.filter(Column("serviceID") == service.id.uuidString).fetchOne(db) {
                    category = firstProv.type
                    subtitle = firstProv.resolvedTarget
                }

                if subtitle.isEmpty, let desc = service.description, !desc.isEmpty {
                    subtitle = desc
                }

                let ports = try ServicePortMapping
                    .filter(Column("serviceID") == service.id.uuidString)
                    .fetchAll(db)
                    .map(\.localPort)

                snapshots.append(
                    ServiceCardSnapshot(
                        id: service.id,
                        name: service.name,
                        groupID: service.groupID,
                        isDisabled: service.isDisabled,
                        isStarred: service.isStarred,
                        subtitle: subtitle,
                        providerCategory: category,
                        portDisplays: ports,
                        createdAt: service.createdAt
                    )
                )
            }

            return snapshots
        }
    }

    public func fetchService(id: UUID) async throws -> Service? {
        try await dbWriter.read { db in
            try Service.fetchOne(db, key: id.uuidString)
        }
    }

    public func toggleStarred(serviceID: UUID) async throws -> Bool {
        try await dbWriter.write { db in
            guard var service = try Service.fetchOne(db, key: serviceID.uuidString) else {
                return false
            }
            service.isStarred.toggle()
            service.updatedAt = Date()
            try service.update(db)
            return service.isStarred
        }
    }

    public func fetchProviders(forService serviceID: UUID) async throws -> [Provider] {
        try await dbWriter.read { db in
            try Provider
                .filter(Column("serviceID") == serviceID.uuidString)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    public func fetchPortMappings(forService serviceID: UUID) async throws -> [ServicePortMapping] {
        try await dbWriter.read { db in
            try ServicePortMapping
                .filter(Column("serviceID") == serviceID.uuidString)
                .fetchAll(db)
        }
    }

    public func insertService(_ service: Service, defaultProvider: Provider?, portMappings: [ServicePortMapping] = []) async throws {
        try await dbWriter.write { db in
            try service.insert(db)
            if let provider = defaultProvider {
                try provider.insert(db)
            }
            for mapping in portMappings {
                try db.execute(
                    sql: "INSERT INTO portMapping (id, serviceID, localPort, remotePort, protocolType) VALUES (?, ?, ?, ?, ?)",
                    arguments: [
                        mapping.id.uuidString,
                        service.id.uuidString,
                        mapping.localPort,
                        mapping.remotePort,
                        mapping.protocolType
                    ]
                )
            }
        }
    }

    public func updateService(_ service: Service) async throws {
        try await dbWriter.write { db in
            try service.update(db)
        }
    }

    public func deleteService(id: UUID) async throws {
        try await dbWriter.write { db in
            _ = try Service.deleteOne(db, key: id.uuidString)
        }
    }

    // MARK: - Group Operations

    public func fetchGroups(forWorkspace workspaceID: UUID) async throws -> [ServiceGroup] {
        try await dbWriter.read { db in
            try ServiceGroup
                .filter(Column("workspaceID") == workspaceID.uuidString)
                .order(Column("sortOrder").asc, Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    public func createGroup(workspaceID: UUID, name: String) async throws -> ServiceGroup {
        try await dbWriter.write { db in
            let count = try ServiceGroup.filter(Column("workspaceID") == workspaceID.uuidString).fetchCount(db)
            let group = ServiceGroup(
                id: UUID(),
                workspaceID: workspaceID,
                name: name,
                sortOrder: count,
                createdAt: Date(),
                updatedAt: Date()
            )
            try group.insert(db)
            return group
        }
    }

    public func renameGroup(id: UUID, newName: String) async throws {
        try await dbWriter.write { db in
            if var group = try ServiceGroup.fetchOne(db, key: id.uuidString) {
                group.name = newName
                group.updatedAt = Date()
                try group.update(db)
            }
        }
    }

    public func deleteGroup(id: UUID) async throws {
        try await dbWriter.write { db in
            // Detach any services assigned to this group
            try db.execute(
                sql: "UPDATE service SET groupID = NULL WHERE groupID = ?",
                arguments: [id.uuidString]
            )
            _ = try ServiceGroup.deleteOne(db, key: id.uuidString)
        }
    }
}
