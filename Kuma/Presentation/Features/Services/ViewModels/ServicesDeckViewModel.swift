import SwiftUI
import Observation

@MainActor
@Observable
public final class ServicesDeckViewModel {
    public var debouncedSearchText: String = ""
    public var searchText: String = "" {
        didSet {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            debouncedSearchText = query
        }
    }
    public var selectedStatuses: Set<ServiceStatusFilterOption> = []
    public var selectedProviders: Set<ProviderCategory> = []
    public var sortBy: ServiceSortOption = .name
    public var viewMode: DeckViewMode = .card
    public var isInspectorPresented: Bool = false
    public var selectedServiceID: UUID? = nil
    public var isStarredOnly: Bool = false
    public var hasInitialLoaded: Bool = false

    // Tier 1: Static Snapshots (~64B per item)
    public var snapshots: [ServiceCardSnapshot] = []

    // Tier 2: Live Runtime States (isolated from static list)
    public var runtimeStates: [UUID: ServiceRuntimeState] = [:]

    private let serviceRepository: any ServiceRepositoryProtocol

    public init(
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository(),
        isStarredOnly: Bool = false
    ) {
        self.serviceRepository = serviceRepository
        self.isStarredOnly = isStarredOnly
    }

    // MARK: - Filtered & Sorted Projections (Ultra-Fast Zero Allocation)

    public var filteredSnapshots: [ServiceCardSnapshot] {
        let query = debouncedSearchText
        let hasSearch = !query.isEmpty
        let hasStatusFilter = !selectedStatuses.isEmpty
        let hasProviderFilter = !selectedProviders.isEmpty
        let starredOnly = isStarredOnly

        // 1. Single-Pass High-Speed Token Matching
        var result = snapshots.filter { snapshot in
            if starredOnly && !snapshot.isStarred {
                return false
            }
            if hasSearch {
                if !snapshot.searchKey.contains(query) {
                    return false
                }
            }

            if hasStatusFilter {
                if snapshot.isDisabled {
                    if !selectedStatuses.contains(.disabled) { return false }
                } else {
                    let state = runtimeStates[snapshot.id]?.status ?? .stopped
                    switch state {
                    case .running, .starting:
                        if !selectedStatuses.contains(.running) { return false }
                    case .stopped, .stopping:
                        if !selectedStatuses.contains(.stopped) { return false }
                    case .crashed:
                        if !selectedStatuses.contains(.crashed) { return false }
                    }
                }
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
            result.sort { a, b in
                let priorityA: Int = a.isDisabled ? 5 : (runtimeStates[a.id]?.status.sortPriority ?? 4)
                let priorityB: Int = b.isDisabled ? 5 : (runtimeStates[b.id]?.status.sortPriority ?? 4)
                
                if priorityA != priorityB {
                    return priorityA < priorityB
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    private var loadTask: Task<Void, Never>? = nil

    // MARK: - Actions

    public func loadWorkspace(workspaceID: UUID) {
        loadTask?.cancel()
        loadTask = Task {
            await loadWorkspaceAsync(workspaceID: workspaceID)
        }
    }

    public func loadWorkspaceAsync(workspaceID: UUID) async {
        do {
            let loaded = try await serviceRepository.fetchSnapshots(forWorkspace: workspaceID)
            guard !Task.isCancelled else { return }
            self.snapshots = loaded
            self.hasInitialLoaded = true

            // Ensure initial runtime state exists for each service
            for snapshot in loaded {
                if self.runtimeStates[snapshot.id] == nil {
                    self.runtimeStates[snapshot.id] = ServiceRuntimeState(status: .stopped, isLoading: false)
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            self.snapshots = []
            self.hasInitialLoaded = true
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

    public func toggleStarred(id: UUID, workspaceID: UUID) {
        // 1. Optimistic zero-latency UI update
        if let idx = snapshots.firstIndex(where: { $0.id == id }) {
            let current = snapshots[idx]
            let updated = ServiceCardSnapshot(
                id: current.id,
                name: current.name,
                isDisabled: current.isDisabled,
                isStarred: !current.isStarred,
                subtitle: current.subtitle,
                providerCategory: current.providerCategory,
                portDisplays: current.portDisplays,
                createdAt: current.createdAt
            )
            snapshots[idx] = updated
        }

        // 2. Asynchronously persist to SQLite
        Task {
            do {
                _ = try await serviceRepository.toggleStarred(serviceID: id)
            } catch {
                // Rollback on failure
                await loadWorkspaceAsync(workspaceID: workspaceID)
            }
        }
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
