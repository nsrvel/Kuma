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

    // Tier 1: Static Snapshots (~64B per item)
    public var snapshots: [ServiceCardSnapshot] = []

    // Tier 2: Live Runtime States (isolated from static list)
    public var runtimeStates: [UUID: ServiceRuntimeState] = [:]

    private let serviceRepository: any ServiceRepositoryProtocol

    public init(serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()) {
        self.serviceRepository = serviceRepository
    }

    // MARK: - Filtered & Sorted Projections

    public var filteredSnapshots: [ServiceCardSnapshot] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSearch = !trimmedQuery.isEmpty
        let hasStatusFilter = !selectedStatuses.isEmpty
        let hasProviderFilter = !selectedProviders.isEmpty

        // 1. Single-Pass Zero-Allocation Filtering
        var result = snapshots.filter { snapshot in
            if hasSearch {
                let nameMatch = snapshot.name.localizedStandardContains(trimmedQuery)
                let subMatch = snapshot.subtitle.localizedStandardContains(trimmedQuery)
                if !nameMatch && !subMatch { return false }
            }

            if hasStatusFilter {
                let state = runtimeStates[snapshot.id]?.status ?? .stopped
                if !selectedStatuses.contains(state) { return false }
            }

            if hasProviderFilter {
                if !selectedProviders.contains(snapshot.providerCategory) { return false }
            }

            return true
        }

        // 2. Sort Order (Natural Status Priority + Stable Alpha Tiebreaker)
        switch sortBy {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .status:
            result.sort {
                let s0 = runtimeStates[$0.id]?.status ?? .stopped
                let s1 = runtimeStates[$1.id]?.status ?? .stopped
                if s0.sortPriority != s1.sortPriority {
                    return s0.sortPriority < s1.sortPriority
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    // MARK: - Actions

    public func loadWorkspace(workspaceID: UUID) {
        Task {
            await loadWorkspaceAsync(workspaceID: workspaceID)
        }
    }

    public func loadWorkspaceAsync(workspaceID: UUID) async {
        do {
            let loaded = try await serviceRepository.fetchSnapshots(forWorkspace: workspaceID)
            self.snapshots = loaded

            // Ensure initial runtime state exists for each service
            for snapshot in loaded {
                if self.runtimeStates[snapshot.id] == nil {
                    self.runtimeStates[snapshot.id] = ServiceRuntimeState(status: .stopped, isLoading: false)
                }
            }
        } catch {
            self.snapshots = []
        }
    }

    public func toggleService(id: UUID) {
        var current = runtimeStates[id] ?? ServiceRuntimeState()
        if current.status.isOperational {
            current.status = .stopped
        } else {
            current.status = .running
        }
        runtimeStates[id] = current
    }

    public func selectService(_ id: UUID) {
        self.selectedServiceID = id
        self.isInspectorPresented = true
    }

    /// Batch apply runtime updates from background actor without invalidating static snapshot array
    public func applyRuntimeDiff(_ diff: [UUID: ServiceRuntimeState]) {
        for (id, state) in diff {
            if self.runtimeStates[id] != state {
                self.runtimeStates[id] = state
            }
        }
    }
}
