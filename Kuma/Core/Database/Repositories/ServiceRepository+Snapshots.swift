import Foundation
import GRDB

extension ServiceRepository {
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

    nonisolated static func portMappingsForActiveProvider(
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
