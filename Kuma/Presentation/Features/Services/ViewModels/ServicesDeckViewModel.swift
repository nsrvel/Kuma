//
//  ServicesDeckViewModel.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Clean @Observable view model driving the Services Deck Stage, Toolbar, and Inspector states.
//

import SwiftUI
import Observation

@MainActor
@Observable
public final class ServicesDeckViewModel {
    public var searchText: String = ""
    public var selectedStatuses: Set<ServiceState> = []
    public var selectedProviders: Set<ProviderCategory> = []
    public var sortBy: ServiceSortOption = .name
    public var viewMode: DeckViewMode = .card
    public var isInspectorPresented: Bool = false
    public var selectedServiceID: UUID? = nil

    public var services: [Service] = []
    public var serviceProviders: [UUID: ProviderCategory] = [:]
    public var portMappings: [UUID: [ServicePortMapping]] = [:]
    public var serviceStates: [UUID: ServiceState] = [:]
    public var loadingServiceIDs: Set<UUID> = []

    public init() {}

    // MARK: - Filtered & Sorted Services

    public var filteredServices: [Service] {
        var result = services

        // Search Filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { service in
                service.name.lowercased().contains(query) ||
                (service.description?.lowercased().contains(query) ?? false)
            }
        }

        // Status Filter
        if !selectedStatuses.isEmpty {
            result = result.filter { service in
                let state = serviceStates[service.id] ?? .stopped
                return selectedStatuses.contains(state)
            }
        }

        // Provider Filter
        if !selectedProviders.isEmpty {
            result = result.filter { service in
                let provider = serviceProviders[service.id] ?? .docker
                return selectedProviders.contains(provider)
            }
        }

        // Sort Order
        switch sortBy {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .status:
            result.sort { (serviceStates[$0.id] ?? .stopped).rawValue < (serviceStates[$1.id] ?? .stopped).rawValue }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    // MARK: - Actions

    public func loadWorkspace(workspaceID: UUID) {
        // Populate sample data for instant interactive visual testing if empty
        if services.isEmpty {
            let s1 = Service(name: "PostgreSQL Database", description: "Docker: postgres:16-alpine", workspaceID: workspaceID)
            let s2 = Service(name: "Redis Cache", description: "Docker: redis:7-alpine", workspaceID: workspaceID)
            let s3 = Service(name: "Backend Node API", description: "npm run start:dev", workspaceID: workspaceID)
            let s4 = Service(name: "Frontend Next.js App", description: "npm run dev", workspaceID: workspaceID)

            self.services = [s1, s2, s3, s4]
            self.serviceProviders[s1.id] = .docker
            self.serviceProviders[s2.id] = .docker
            self.serviceProviders[s3.id] = .shell
            self.serviceProviders[s4.id] = .shell

            self.portMappings[s1.id] = [ServicePortMapping(localPort: 5432, remotePort: 5432)]
            self.portMappings[s2.id] = [ServicePortMapping(localPort: 6379, remotePort: 6379)]
            self.portMappings[s3.id] = [ServicePortMapping(localPort: 8080, remotePort: 8080)]
            self.portMappings[s4.id] = [ServicePortMapping(localPort: 3000, remotePort: 3000)]

            self.serviceStates[s1.id] = .running
            self.serviceStates[s2.id] = .running
            self.serviceStates[s3.id] = .stopped
            self.serviceStates[s4.id] = .stopped
        }
    }

    public func toggleService(_ service: Service) {
        let current = serviceStates[service.id] ?? .stopped
        if current.isOperational {
            serviceStates[service.id] = .stopped
        } else {
            serviceStates[service.id] = .running
        }
    }

    public func selectService(_ id: UUID) {
        self.selectedServiceID = id
        self.isInspectorPresented = true
    }
}
