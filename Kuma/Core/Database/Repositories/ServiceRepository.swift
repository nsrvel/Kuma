import Foundation
import GRDB

public protocol ServiceRepositoryProtocol: Sendable {
    func fetchSnapshots(forWorkspace workspaceID: UUID) async throws -> [ServiceCardSnapshot]
    func fetchSnapshot(serviceID: UUID) async throws -> ServiceCardSnapshot?
    func fetchService(id: UUID) async throws -> Service?
    func fetchServiceDetail(id: UUID) async throws -> (service: Service, providers: [Provider], portMappings: [ServicePortMapping])?
    func fetchProviders(forService serviceID: UUID) async throws -> [Provider]
    func fetchPortMappings(forService serviceID: UUID) async throws -> [ServicePortMapping]
    func fetchPortMappings(forService serviceID: UUID, providerID: UUID) async throws -> [ServicePortMapping]
    func fetchAllPortMappings() async throws -> [ServicePortMapping]
    func insertService(_ service: Service, defaultProvider: Provider?, portMappings: [ServicePortMapping]) async throws
    func updateService(_ service: Service) async throws
    func insertProvider(_ provider: Provider) async throws
    func updateProvider(_ provider: Provider) async throws
    func deleteProvider(id: UUID) async throws
    func savePortMappings(_ portMappings: [ServicePortMapping], forService serviceID: UUID, providerID: UUID) async throws
    func toggleStarred(serviceID: UUID) async throws -> Bool
    func toggleGroupMembership(serviceID: UUID, groupID: UUID) async throws -> Set<UUID>
    func deleteService(id: UUID) async throws
    func duplicateService(sourceID: UUID, newID: UUID) async throws -> Service
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
            for service in services {
                let activeProvID = service.activeProviderID ?? providersByServiceID[service.id]?.first?.id
                let ports = Self.localPortsForActiveProvider(
                    mappings: allPortMappings,
                    serviceID: service.id,
                    activeProviderID: activeProvID
                )
                portsByServiceID[service.id] = ports
            }

            // Batch fetch all group memberships for all services in this workspace in 1 query
            let allMemberships = try ServiceGroupMembershipRecord
                .filter(serviceIDStrings.contains(Column("serviceID")))
                .fetchAll(db)

            var groupsByServiceID: [UUID: Set<UUID>] = [:]
            groupsByServiceID.reserveCapacity(services.count)
            for membership in allMemberships {
                groupsByServiceID[membership.serviceID, default: []].insert(membership.groupID)
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
                let groupIDs = groupsByServiceID[service.id] ?? []
                let provs = providersByServiceID[service.id] ?? []
                let activeID = service.activeProviderID ?? provs.first?.id
                let providerOptions = provs.map { p in
                    let displayLabel: String
                    if let lbl = p.label, !lbl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        displayLabel = lbl
                    } else {
                        displayLabel = p.type.sidebarLabel
                    }
                    return ServiceCardSnapshot.ProviderOption(
                        id: p.id,
                        category: p.type,
                        label: displayLabel,
                        isActive: (p.id == activeID)
                    )
                }

                snapshots.append(
                    ServiceCardSnapshot(
                        id: service.id,
                        name: service.name,
                        groupIDs: groupIDs,
                        isDisabled: service.isDisabled,
                        isStarred: service.isStarred,
                        subtitle: subtitle,
                        providerCategory: category,
                        portDisplays: ports,
                        providerOptions: providerOptions,
                        createdAt: service.createdAt
                    )
                )
            }

            return snapshots
        }
    }

    public func fetchSnapshot(serviceID: UUID) async throws -> ServiceCardSnapshot? {
        try await dbWriter.read { db in
            guard let service = try Service.fetchOne(db, key: serviceID.uuidString) else { return nil }

            let providers = try Provider
                .filter(Column("serviceID") == serviceID.uuidString)
                .order(Column("createdAt").asc)
                .fetchAll(db)

            let portMappings = try ServicePortMapping
                .filter(Column("serviceID") == serviceID.uuidString)
                .fetchAll(db)

            let activeProvID = service.activeProviderID ?? providers.first?.id
            let activePorts = Self.localPortsForActiveProvider(
                mappings: portMappings,
                serviceID: service.id,
                activeProviderID: activeProvID
            )

            let memberships = try ServiceGroupMembershipRecord
                .filter(Column("serviceID") == serviceID.uuidString)
                .fetchAll(db)

            var category: ProviderCategory = .docker
            var subtitle: String = service.description ?? ""

            if let activeProvID = service.activeProviderID,
               let provider = providers.first(where: { $0.id == activeProvID }) {
                category = provider.type
                subtitle = provider.resolvedTarget
            } else if let firstProv = providers.first {
                category = firstProv.type
                subtitle = firstProv.resolvedTarget
            }

            if subtitle.isEmpty, let desc = service.description, !desc.isEmpty {
                subtitle = desc
            }

            let ports = activePorts
            let groupIDs = Set(memberships.map(\.groupID))
            let activeID = activeProvID
            let providerOptions = providers.map { p in
                let displayLabel: String
                if let lbl = p.label, !lbl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    displayLabel = lbl
                } else {
                    displayLabel = p.type.sidebarLabel
                }
                return ServiceCardSnapshot.ProviderOption(
                    id: p.id,
                    category: p.type,
                    label: displayLabel,
                    isActive: (p.id == activeID)
                )
            }

            return ServiceCardSnapshot(
                id: service.id,
                name: service.name,
                groupIDs: groupIDs,
                isDisabled: service.isDisabled,
                isStarred: service.isStarred,
                subtitle: subtitle,
                providerCategory: category,
                portDisplays: ports,
                providerOptions: providerOptions,
                createdAt: service.createdAt
            )
        }
    }

    public func fetchService(id: UUID) async throws -> Service? {
        try await dbWriter.read { db in
            guard var service = try Service.fetchOne(db, key: id.uuidString) else { return nil }
            let memberships = try ServiceGroupMembershipRecord
                .filter(Column("serviceID") == id.uuidString)
                .fetchAll(db)
            service.groupIDs = Set(memberships.map { $0.groupID })
            return service
        }
    }

    /// Unified single-transaction query fetching a Service, all its Providers, and all its PortMappings in 1 read transaction.
    public func fetchServiceDetail(id: UUID) async throws -> (service: Service, providers: [Provider], portMappings: [ServicePortMapping])? {
        try await dbWriter.read { db in
            guard var service = try Service.fetchOne(db, key: id.uuidString) else { return nil }
            let memberships = try ServiceGroupMembershipRecord
                .filter(Column("serviceID") == id.uuidString)
                .fetchAll(db)
            service.groupIDs = Set(memberships.map { $0.groupID })

            let providers = try Provider
                .filter(Column("serviceID") == id.uuidString)
                .order(Column("createdAt").asc)
                .fetchAll(db)

            let allPortMappings = try ServicePortMapping
                .filter(Column("serviceID") == id.uuidString)
                .fetchAll(db)

            let activeProvID = service.activeProviderID ?? providers.first?.id
            let portMappings = Self.portMappingsForActiveProvider(
                mappings: allPortMappings,
                serviceID: service.id,
                activeProviderID: activeProvID
            )

            return (service: service, providers: providers, portMappings: portMappings)
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
            guard let service = try Service.fetchOne(db, key: serviceID.uuidString) else { return [] }
            let providers = try Provider
                .filter(Column("serviceID") == serviceID.uuidString)
                .order(Column("createdAt").asc)
                .fetchAll(db)
            let all = try ServicePortMapping
                .filter(Column("serviceID") == serviceID.uuidString)
                .fetchAll(db)
            let activeProvID = service.activeProviderID ?? providers.first?.id
            return Self.portMappingsForActiveProvider(
                mappings: all,
                serviceID: serviceID,
                activeProviderID: activeProvID
            )
        }
    }

    public func fetchPortMappings(forService serviceID: UUID, providerID: UUID) async throws -> [ServicePortMapping] {
        try await dbWriter.read { db in
            let all = try ServicePortMapping
                .filter(Column("serviceID") == serviceID.uuidString)
                .fetchAll(db)
            return Self.portMappingsForActiveProvider(
                mappings: all,
                serviceID: serviceID,
                activeProviderID: providerID
            )
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
                if mapping.providerID == nil {
                    mapping.providerID = defaultProvider?.id
                }
                try mapping.insert(db)
            }
            for groupID in service.groupIDs {
                let membership = ServiceGroupMembershipRecord(serviceID: service.id, groupID: groupID)
                try membership.insert(db)
            }
        }
    }

    public func updateService(_ service: Service) async throws {
        try await dbWriter.write { db in
            try service.update(db)

            _ = try ServiceGroupMembershipRecord
                .filter(Column("serviceID") == service.id.uuidString)
                .deleteAll(db)

            for groupID in service.groupIDs {
                let membership = ServiceGroupMembershipRecord(serviceID: service.id, groupID: groupID)
                try membership.insert(db)
            }
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

    public func savePortMappings(
        _ portMappings: [ServicePortMapping],
        forService serviceID: UUID,
        providerID: UUID
    ) async throws {
        try await dbWriter.write { db in
            _ = try ServicePortMapping
                .filter(Column("serviceID") == serviceID.uuidString && Column("providerID") == providerID.uuidString)
                .deleteAll(db)

            var seenIDs = Set<UUID>()
            for var mapping in portMappings {
                mapping.serviceID = serviceID
                mapping.providerID = providerID
                if seenIDs.contains(mapping.id) {
                    mapping.id = UUID()
                }
                seenIDs.insert(mapping.id)
                try mapping.insert(db)
            }
        }
    }

    public func toggleGroupMembership(serviceID: UUID, groupID: UUID) async throws -> Set<UUID> {
        try await dbWriter.write { db in
            let existing = try ServiceGroupMembershipRecord
                .filter(Column("serviceID") == serviceID.uuidString && Column("groupID") == groupID.uuidString)
                .fetchOne(db)

            if let existing {
                _ = try existing.delete(db)
            } else {
                let membership = ServiceGroupMembershipRecord(serviceID: serviceID, groupID: groupID)
                try membership.insert(db)
            }

            let all = try ServiceGroupMembershipRecord
                .filter(Column("serviceID") == serviceID.uuidString)
                .fetchAll(db)

            return Set(all.map { $0.groupID })
        }
    }

    public func deleteService(id: UUID) async throws {
        try await dbWriter.write { db in
            _ = try Service.deleteOne(db, key: id.uuidString)
        }
    }

    /// Single atomic SQLite transaction for duplicating a service along with all its providers, port mappings, and group memberships
    public func duplicateService(sourceID: UUID, newID: UUID) async throws -> Service {
        try await dbWriter.write { db -> Service in
            guard let original = try Service.fetchOne(db, key: sourceID.uuidString) else {
                throw NSError(domain: "lokastudio.kuma", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source service not found"])
            }

            let providers = try Provider
                .filter(Column("serviceID") == sourceID.uuidString)
                .order(Column("createdAt").asc)
                .fetchAll(db)

            let ports = try ServicePortMapping
                .filter(Column("serviceID") == sourceID.uuidString)
                .fetchAll(db)

            let memberships = try ServiceGroupMembershipRecord
                .filter(Column("serviceID") == sourceID.uuidString)
                .fetchAll(db)

            var newService = original
            newService.id = newID
            newService.name = "\(original.name) (Copy)"
            newService.createdAt = Date()
            newService.updatedAt = Date()

            var newActiveProvID: UUID? = nil
            var providerIDMap: [UUID: UUID] = [:]
            var duplicatedProviders: [Provider] = []

            for prov in providers {
                var newProv = prov
                let newProvID = UUID()
                providerIDMap[prov.id] = newProvID
                newProv.id = newProvID
                newProv.serviceID = newID
                newProv.createdAt = Date()
                newProv.updatedAt = Date()
                if prov.id == original.activeProviderID {
                    newActiveProvID = newProv.id
                }
                duplicatedProviders.append(newProv)
            }

            if newActiveProvID == nil {
                newActiveProvID = duplicatedProviders.first?.id
            }
            newService.activeProviderID = newActiveProvID

            // 1. Insert new service
            try newService.insert(db)

            // 2. Insert duplicated providers
            for prov in duplicatedProviders {
                try prov.insert(db)
            }

            // 3. Insert duplicated port mappings (per provider)
            for p in ports {
                let targetProvID = p.providerID.flatMap { providerIDMap[$0] } ?? newActiveProvID
                guard let targetProvID else { continue }
                let newPort = ServicePortMapping(
                    id: UUID(),
                    serviceID: newID,
                    providerID: targetProvID,
                    localPort: p.localPort,
                    remotePort: p.remotePort,
                    protocolType: p.protocolType
                )
                try newPort.insert(db)
            }

            // 4. Insert duplicated group memberships
            for m in memberships {
                let newMem = ServiceGroupMembershipRecord(serviceID: newID, groupID: m.groupID)
                try newMem.insert(db)
            }

            return newService
        }
    }

    private nonisolated static func portMappingsForActiveProvider(
        mappings: [ServicePortMapping],
        serviceID: UUID,
        activeProviderID: UUID?
    ) -> [ServicePortMapping] {
        guard let activeProviderID else { return [] }
        let scoped = mappings.filter { $0.serviceID == serviceID || $0.serviceID == nil }
        let forProvider = scoped.filter { $0.providerID == activeProviderID }
        if !forProvider.isEmpty {
            return forProvider
        }
        // Legacy rows without providerID: treat as active provider only when unambiguous.
        let legacy = scoped.filter { $0.providerID == nil }
        if legacy.count == scoped.count {
            return legacy
        }
        return []
    }

    private nonisolated static func localPortsForActiveProvider(
        mappings: [ServicePortMapping],
        serviceID: UUID,
        activeProviderID: UUID?
    ) -> [Int] {
        portMappingsForActiveProvider(
            mappings: mappings,
            serviceID: serviceID,
            activeProviderID: activeProviderID
        ).map(\.localPort)
    }
}

