import Foundation
import GRDB

public protocol ServiceRepositoryProtocol: Sendable {
    func fetchSnapshots(forWorkspace workspaceID: UUID) async throws -> [ServiceCardSnapshot]
    func fetchService(id: UUID) async throws -> Service?
    func fetchProviders(forService serviceID: UUID) async throws -> [Provider]
    func fetchPortMappings(forService serviceID: UUID) async throws -> [ServicePortMapping]
    func fetchAllPortMappings() async throws -> [ServicePortMapping]
    func insertService(_ service: Service, defaultProvider: Provider?, portMappings: [ServicePortMapping]) async throws
    func updateService(_ service: Service) async throws
    func insertProvider(_ provider: Provider) async throws
    func updateProvider(_ provider: Provider) async throws
    func deleteProvider(id: UUID) async throws
    func savePortMappings(_ portMappings: [ServicePortMapping], forService serviceID: UUID) async throws
    func toggleStarred(serviceID: UUID) async throws -> Bool
    func deleteService(id: UUID) async throws
}


/// `@unchecked Sendable`: Thread safety is guaranteed by GRDB's underlying `DatabaseWriter` (DatabasePool / DatabaseQueue)
/// which synchronizes access via serialized dispatch queues. Do not add mutable stored properties to this class.
public final class ServiceRepository: ServiceRepositoryProtocol, @unchecked Sendable {
    private let dbWriter: any DatabaseWriter


    public nonisolated init(dbWriter: (any DatabaseWriter)? = nil) {
        self.dbWriter = dbWriter ?? AppDatabase.shared.dbWriter
    }

    /// High-performance projection query: Reads only necessary fields for UI list using batch queries (O(1) in-memory dictionary lookups, zero N+1 database roundtrips)
    public func fetchSnapshots(forWorkspace workspaceID: UUID) async throws -> [ServiceCardSnapshot] {
        try await dbWriter.read { db in
            let services = try Service
                .filter(Column("workspaceID") == workspaceID.uuidString)
                .order(Column("createdAt").asc)
                .fetchAll(db)

            guard !services.isEmpty else { return [] }

            let serviceIDStrings = services.map { $0.id.uuidString }

            // Batch fetch all providers for all services in this workspace in 1 query
            let allProviders = try Provider
                .filter(serviceIDStrings.contains(Column("serviceID")))
                .order(Column("createdAt").asc)
                .fetchAll(db)

            // Map providers by service ID (ordered by creation) and by provider ID
            var providersByServiceID: [UUID: [Provider]] = [:]
            var providerByID: [UUID: Provider] = [:]
            providersByServiceID.reserveCapacity(services.count)
            providerByID.reserveCapacity(allProviders.count)

            for provider in allProviders {
                providersByServiceID[provider.serviceID, default: []].append(provider)
                providerByID[provider.id] = provider
            }

            // Batch fetch all port mappings for all services in this workspace in 1 query
            let allPortMappings = try ServicePortMapping
                .filter(serviceIDStrings.contains(Column("serviceID")))
                .fetchAll(db)

            var portsByServiceID: [UUID: [Int]] = [:]
            portsByServiceID.reserveCapacity(services.count)
            for mapping in allPortMappings {
                if let sID = mapping.serviceID {
                    portsByServiceID[sID, default: []].append(mapping.localPort)
                }
            }

            var snapshots: [ServiceCardSnapshot] = []
            snapshots.reserveCapacity(services.count)

            for service in services {
                var category: ProviderCategory = .docker
                var subtitle: String = service.description ?? ""

                if let activeProvID = service.activeProviderID,
                   let provider = providerByID[activeProvID] {
                    category = provider.type
                    subtitle = provider.resolvedTarget
                } else if let firstProv = providersByServiceID[service.id]?.first {
                    category = firstProv.type
                    subtitle = firstProv.resolvedTarget
                }

                if subtitle.isEmpty, let desc = service.description, !desc.isEmpty {
                    subtitle = desc
                }

                let ports = portsByServiceID[service.id] ?? []

                snapshots.append(
                    ServiceCardSnapshot(
                        id: service.id,
                        name: service.name,
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

    public func fetchAllPortMappings() async throws -> [ServicePortMapping] {
        try await dbWriter.read { db in
            try ServicePortMapping.fetchAll(db)
        }
    }

    public func insertService(_ service: Service, defaultProvider: Provider?, portMappings: [ServicePortMapping] = []) async throws {
        try await dbWriter.write { db in
            try service.insert(db)
            if let provider = defaultProvider {
                try provider.insert(db)
            }
            for var mapping in portMappings {
                mapping.serviceID = service.id
                try mapping.insert(db)
            }
        }
    }

    public func updateService(_ service: Service) async throws {
        try await dbWriter.write { db in
            try service.update(db)
        }
    }

    public func insertProvider(_ provider: Provider) async throws {
        try await dbWriter.write { db in
            try provider.insert(db)
        }
    }

    public func updateProvider(_ provider: Provider) async throws {
        try await dbWriter.write { db in
            try provider.update(db)
        }
    }

    public func deleteProvider(id: UUID) async throws {
        try await dbWriter.write { db in
            _ = try Provider.deleteOne(db, key: id.uuidString)
        }
    }

    public func savePortMappings(_ portMappings: [ServicePortMapping], forService serviceID: UUID) async throws {
        try await dbWriter.write { db in
            // Delete old port mappings for this service
            _ = try ServicePortMapping
                .filter(Column("serviceID") == serviceID.uuidString)
                .deleteAll(db)

            // Insert new mappings using typed GRDB API
            for var mapping in portMappings {
                mapping.serviceID = serviceID
                try mapping.insert(db)
            }
        }
    }

    public func deleteService(id: UUID) async throws {
        try await dbWriter.write { db in
            _ = try Service.deleteOne(db, key: id.uuidString)
        }
    }
}

