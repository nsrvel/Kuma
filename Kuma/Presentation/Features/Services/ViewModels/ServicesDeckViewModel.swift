import SwiftUI
import Observation
import os

@MainActor
@Observable
public final class ServicesDeckViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ServicesDeckViewModel")

    // MARK: - Filter Inputs (each triggers recompute on change)

    public var searchText: String = "" {
        didSet { if oldValue != searchText { recomputeFilteredSnapshots() } }
    }
    public var selectedStatuses: Set<ServiceStatusFilterOption> = [] {
        didSet { if oldValue != selectedStatuses { recomputeFilteredSnapshots() } }
    }
    public var selectedProviders: Set<ProviderCategory> = [] {
        didSet { if oldValue != selectedProviders { recomputeFilteredSnapshots() } }
    }
    public var sortBy: ServiceSortOption = .name {
        didSet { if oldValue != sortBy { recomputeFilteredSnapshots() } }
    }
    public var isStarredOnly: Bool = false {
        didSet { if oldValue != isStarredOnly { recomputeFilteredSnapshots() } }
    }

    // MARK: - Non-Filter State (changes do NOT trigger recompute)

    public var viewMode: DeckViewMode = .card
    public var isInspectorPresented: Bool = false
    public var selectedServiceID: UUID? = nil
    public var hasInitialLoaded: Bool = false

    // MARK: - Tier 1: Static Snapshots (~64B per item)

    public var snapshots: [ServiceCardSnapshot] = [] {
        didSet { recomputeFilteredSnapshots() }
    }

    // MARK: - Tier 2: Cached Filtered Output (B1 Fix)

    /// Cached filtered + sorted projection. Updated only when filter inputs or snapshots change.
    public private(set) var filteredSnapshots: [ServiceCardSnapshot] = []

    /// Monotonic version counter for lightweight animation tracking (B2 Fix).
    /// Views use this instead of diffing the full [ServiceCardSnapshot] array.
    public private(set) var filterVersion: Int = 0

    // MARK: - Tier 3: Live Runtime States (isolated from static list)

    public var runtimeStates: [UUID: ServiceRuntimeState] = [:]

    private let serviceRepository: any ServiceRepositoryProtocol
    private var loadTask: Task<Void, Never>? = nil

    public init(
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository(),
        isStarredOnly: Bool = false
    ) {
        self.serviceRepository = serviceRepository
        self.isStarredOnly = isStarredOnly
    }

    // MARK: - Filtered & Sorted Projection Engine

    /// Explicitly recomputes the cached filteredSnapshots.
    /// Called by didSet observers on filter inputs, snapshots, and by runtime-aware methods.
    private func recomputeFilteredSnapshots() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

        filteredSnapshots = result
        filterVersion += 1
    }

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

            // Seed initial runtime states before setting snapshots (which triggers recompute)
            for snapshot in loaded {
                if self.runtimeStates[snapshot.id] == nil {
                    self.runtimeStates[snapshot.id] = .idle
                }
            }

            self.snapshots = loaded
            self.hasInitialLoaded = true
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error("Failed to load snapshots for workspace \(workspaceID): \(error.localizedDescription)")
            self.snapshots = []
            self.hasInitialLoaded = true
        }
    }

    public func toggleService(id: UUID) {
        Task {
            await toggleServiceAsync(id: id)
        }
    }

    public func toggleServiceAsync(id: UUID) async {
        var current = runtimeStates[id] ?? .idle
        let wasRunning = current.status.isOperational

        // Smooth state transition without actual OS subprocess execution
        current.isLoading = true
        runtimeStates[id] = current

        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms natural tactile delay

        var updated = runtimeStates[id] ?? .idle
        updated.status = wasRunning ? .stopped : .running
        updated.isLoading = false
        runtimeStates[id] = updated

        // Recompute if status filter is active or sorting depends on status
        if !selectedStatuses.isEmpty || sortBy == .status {
            recomputeFilteredSnapshots()
        }
    }

    public func toggleStarred(id: UUID, workspaceID: UUID) {
        // 1. Optimistic zero-latency UI update (struct copy, no searchKey recompute)
        if let idx = snapshots.firstIndex(where: { $0.id == id }) {
            snapshots[idx] = snapshots[idx].toggling(starred: !snapshots[idx].isStarred)
        }

        // 2. Asynchronously persist to SQLite
        Task {
            do {
                _ = try await serviceRepository.toggleStarred(serviceID: id)
            } catch {
                Self.logger.error("Failed to persist toggleStarred for service \(id): \(error.localizedDescription)")
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
        var changed = false
        for (id, state) in diff {
            if self.runtimeStates[id] != state {
                self.runtimeStates[id] = state
                changed = true
            }
        }
        if changed && (!selectedStatuses.isEmpty || sortBy == .status) {
            recomputeFilteredSnapshots()
        }
    }
}
