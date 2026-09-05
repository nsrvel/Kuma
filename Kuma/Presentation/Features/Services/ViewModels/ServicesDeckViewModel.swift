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
    public var filterGroupID: UUID? = nil {
        didSet { if oldValue != filterGroupID { recomputeFilteredSnapshots() } }
    }

    // MARK: - Non-Filter State (changes do NOT trigger recompute)

    public var viewMode: DeckViewMode = .card
    public var isInspectorPresented: Bool = false
    public var selectedServiceID: UUID? = nil
    public var hasInitialLoaded: Bool = false
    public var servicePendingDeletion: ServiceCardSnapshot? = nil

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

    public var runningServiceCount: Int {
        snapshots.filter { runtimeStates[$0.id]?.status.isOperational == true }.count
    }

    public var stoppedServiceCount: Int {
        snapshots.filter { !($0.isDisabled) && runtimeStates[$0.id]?.status.isOperational != true }.count
    }

    // MARK: - Groups Data
    public var groups: [ServiceGroup] = []

    private let serviceRepository: any ServiceRepositoryProtocol
    private let groupRepository: any ServiceGroupRepositoryProtocol
    private var loadTask: Task<Void, Never>? = nil

    public init(
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository(),
        groupRepository: any ServiceGroupRepositoryProtocol = ServiceGroupRepository(),
        isStarredOnly: Bool = false,
        filterGroupID: UUID? = nil
    ) {
        self.serviceRepository = serviceRepository
        self.groupRepository = groupRepository
        self.isStarredOnly = isStarredOnly
        self.filterGroupID = filterGroupID
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
        let targetGroupID = filterGroupID

        // 1. Single-Pass High-Speed Token Matching
        var result = snapshots.filter { snapshot in
            if starredOnly && !snapshot.isStarred {
                return false
            }
            if let targetGroupID, !snapshot.groupIDs.contains(targetGroupID) {
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
            async let loadedSnapshots = serviceRepository.fetchSnapshots(forWorkspace: workspaceID)
            async let loadedGroups = groupRepository.fetchAll(workspaceID: workspaceID)

            let (loaded, groups) = try await (loadedSnapshots, loadedGroups)
            guard !Task.isCancelled else { return }

            // Seed or refresh live runtime states from ProcessRegistry
            for snapshot in loaded {
                let isProcessActive = await ProcessRegistry.shared.isRunning(serviceID: snapshot.id)
                let currentStatus = self.runtimeStates[snapshot.id]?.status ?? (isProcessActive ? .running : .stopped)
                self.runtimeStates[snapshot.id] = ServiceRuntimeState(status: isProcessActive ? .running : (currentStatus == .running ? .stopped : currentStatus), isLoading: false)
            }

            self.groups = groups
            self.snapshots = loaded
            self.hasInitialLoaded = true
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error("Failed to load workspace \(workspaceID): \(error.localizedDescription)")
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
        let wasRunning = (runtimeStates[id] ?? .idle).status.isOperational

        if wasRunning {
            runtimeStates[id] = ServiceRuntimeState(status: .stopping, isLoading: true)
            await ServiceExecutionEngine.shared.stop(serviceID: id)
            runtimeStates[id] = ServiceRuntimeState(status: .stopped, isLoading: false)
        } else {
            runtimeStates[id] = ServiceRuntimeState(status: .starting, isLoading: true)
            do {
                try await ServiceExecutionEngine.shared.start(serviceID: id)
                runtimeStates[id] = ServiceRuntimeState(status: .running, isLoading: false)
            } catch {
                Self.logger.error("Failed to start service \(id): \(error.localizedDescription)")
                runtimeStates[id] = ServiceRuntimeState(status: .crashed, isLoading: false)
            }
        }

        // Recompute if status filter is active or sorting depends on status
        if !selectedStatuses.isEmpty || sortBy == .status {
            recomputeFilteredSnapshots()
        }
    }

    public func startAllServices() {
        Task {
            let targetSnapshots = snapshots.filter { !($0.isDisabled) && runtimeStates[$0.id]?.status.isOperational != true }
            
            // Staggered launch: starts services sequentially with a 150ms delay between each
            // to avoid extreme spikes in CPU, network socket binds, or OS process limits.
            for snapshot in targetSnapshots {
                runtimeStates[snapshot.id] = ServiceRuntimeState(status: .starting, isLoading: true)
                do {
                    try await ServiceExecutionEngine.shared.start(serviceID: snapshot.id)
                    runtimeStates[snapshot.id] = ServiceRuntimeState(status: .running, isLoading: false)
                } catch {
                    Self.logger.error("Failed to start service \(snapshot.name): \(error.localizedDescription)")
                    runtimeStates[snapshot.id] = ServiceRuntimeState(status: .crashed, isLoading: false)
                }
                
                // 150ms gentle stagger gap
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            
            if !selectedStatuses.isEmpty || sortBy == .status {
                recomputeFilteredSnapshots()
            }
        }
    }

    public func stopAllServices() {
        Task {
            let runningIDs = snapshots
                .map(\.id)
                .filter { runtimeStates[$0]?.status.isOperational == true }
            
            // Mark all as stopping immediately for UI responsiveness
            for id in runningIDs {
                runtimeStates[id] = ServiceRuntimeState(status: .stopping, isLoading: true)
            }
            
            // Stop services cleanly
            for id in runningIDs {
                await ServiceExecutionEngine.shared.stop(serviceID: id)
                runtimeStates[id] = ServiceRuntimeState(status: .stopped, isLoading: false)
            }
            
            if !selectedStatuses.isEmpty || sortBy == .status {
                recomputeFilteredSnapshots()
            }
        }
    }

    public func restartService(id: UUID) {
        Task {
            runtimeStates[id] = ServiceRuntimeState(status: .stopping, isLoading: true)
            await ServiceExecutionEngine.shared.stop(serviceID: id)
            try? await Task.sleep(nanoseconds: 300_000_000)

            runtimeStates[id] = ServiceRuntimeState(status: .starting, isLoading: true)
            do {
                try await ServiceExecutionEngine.shared.start(serviceID: id)
                runtimeStates[id] = ServiceRuntimeState(status: .running, isLoading: false)
            } catch {
                Self.logger.error("Failed to restart service \(id): \(error.localizedDescription)")
                runtimeStates[id] = ServiceRuntimeState(status: .crashed, isLoading: false)
            }

            if !selectedStatuses.isEmpty || sortBy == .status {
                recomputeFilteredSnapshots()
            }
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
                NotificationCenter.default.post(name: .kumaServiceUpdated, object: id)
            } catch {
                Self.logger.error("Failed to persist toggleStarred for service \(id): \(error.localizedDescription)")
                // Rollback on failure
                await loadWorkspaceAsync(workspaceID: workspaceID)
            }
        }
    }

    public func toggleDisabled(id: UUID, workspaceID: UUID) {
        guard let idx = snapshots.firstIndex(where: { $0.id == id }) else { return }
        let newDisabled = !snapshots[idx].isDisabled

        // 1. Optimistic Update
        let old = snapshots[idx]
        snapshots[idx] = ServiceCardSnapshot(
            id: old.id,
            name: old.name,
            groupIDs: old.groupIDs,
            isDisabled: newDisabled,
            isStarred: old.isStarred,
            subtitle: old.subtitle,
            providerCategory: old.providerCategory,
            portDisplays: old.portDisplays,
            providerOptions: old.providerOptions,
            createdAt: old.createdAt
        )

        // If disabling, also stop runtime
        if newDisabled {
            var rt = runtimeStates[id] ?? .idle
            rt.status = .stopped
            runtimeStates[id] = rt
        }

        // 2. Persist
        Task {
            do {
                if var svc = try await serviceRepository.fetchService(id: id) {
                    svc.isDisabled = newDisabled
                    svc.updatedAt = Date()
                    try await serviceRepository.updateService(svc)
                    NotificationCenter.default.post(name: .kumaServiceUpdated, object: id)
                }
            } catch {
                Self.logger.error("Failed to toggle disabled for service \(id): \(error)")
                await loadWorkspaceAsync(workspaceID: workspaceID)
            }
        }
    }

    public func switchProvider(serviceID: UUID, providerID: UUID, workspaceID: UUID) {
        let isCurrentlyRunning = runtimeStates[serviceID]?.status.isOperational == true

        Task {
            do {
                // If service is running, seamlessly stop old runner before switching
                if isCurrentlyRunning {
                    runtimeStates[serviceID] = ServiceRuntimeState(status: .stopping, isLoading: true)
                    await ServiceExecutionEngine.shared.stop(serviceID: serviceID)
                }

                if var svc = try await serviceRepository.fetchService(id: serviceID) {
                    svc.activeProviderID = providerID
                    svc.updatedAt = Date()
                    try await serviceRepository.updateService(svc)
                    await loadWorkspaceAsync(workspaceID: workspaceID)
                    NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)

                    // If it was running, restart immediately with new provider runner
                    if isCurrentlyRunning {
                        runtimeStates[serviceID] = ServiceRuntimeState(status: .starting, isLoading: true)
                        try await ServiceExecutionEngine.shared.start(serviceID: serviceID)
                        runtimeStates[serviceID] = ServiceRuntimeState(status: .running, isLoading: false)
                    }
                }
            } catch {
                Self.logger.error("Failed to switch provider for service \(serviceID): \(error)")
                runtimeStates[serviceID] = ServiceRuntimeState(status: .crashed, isLoading: false)
                await loadWorkspaceAsync(workspaceID: workspaceID)
            }
        }
    }

    public func toggleGroup(serviceID: UUID, groupID: UUID, workspaceID: UUID) {
        guard let idx = snapshots.firstIndex(where: { $0.id == serviceID }) else { return }

        // 1. Optimistic Update
        let old = snapshots[idx]
        var updatedGroupIDs = old.groupIDs
        if updatedGroupIDs.contains(groupID) {
            updatedGroupIDs.remove(groupID)
        } else {
            updatedGroupIDs.insert(groupID)
        }

        snapshots[idx] = ServiceCardSnapshot(
            id: old.id,
            name: old.name,
            groupIDs: updatedGroupIDs,
            isDisabled: old.isDisabled,
            isStarred: old.isStarred,
            subtitle: old.subtitle,
            providerCategory: old.providerCategory,
            portDisplays: old.portDisplays,
            providerOptions: old.providerOptions,
            createdAt: old.createdAt
        )

        if filterGroupID != nil {
            recomputeFilteredSnapshots()
        }

        // 2. Persist
        Task {
            do {
                _ = try await serviceRepository.toggleGroupMembership(serviceID: serviceID, groupID: groupID)
                NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
            } catch {
                Self.logger.error("Failed to toggle group membership for service \(serviceID): \(error)")
                await loadWorkspaceAsync(workspaceID: workspaceID)
            }
        }
    }

    public func duplicateService(id: UUID, workspaceID: UUID) {
        guard let original = snapshots.first(where: { $0.id == id }) else { return }

        let newServiceID = UUID()
        let optimisticSnapshot = ServiceCardSnapshot(
            id: newServiceID,
            name: "\(original.name) (Copy)",
            groupIDs: original.groupIDs,
            isDisabled: original.isDisabled,
            isStarred: original.isStarred,
            subtitle: original.subtitle,
            providerCategory: original.providerCategory,
            portDisplays: original.portDisplays,
            providerOptions: original.providerOptions,
            createdAt: Date()
        )

        // Instant optimistic UI insertion (0ms perceived latency)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            snapshots.append(optimisticSnapshot)
            recomputeFilteredSnapshots()
        }

        Task {
            do {
                _ = try await serviceRepository.duplicateService(sourceID: id, newID: newServiceID)
                await loadWorkspaceAsync(workspaceID: workspaceID)
                NotificationCenter.default.post(name: .kumaServiceCreated, object: newServiceID)
            } catch {
                Self.logger.error("Failed to duplicate service \(id): \(error)")
                await loadWorkspaceAsync(workspaceID: workspaceID)
            }
        }
    }

    public func copyConfig(id: UUID) {
        Task { @MainActor in
            do {
                let dataPort = DataPortRepository()
                let jsonString = try await dataPort.exportSingleServiceJSON(serviceID: id)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(jsonString, forType: .string)
                NSSound(named: "Purr")?.play()
            } catch {
                Self.logger.error("Failed to copy config for service \(id): \(error)")
            }
        }
    }

    public func promptDeleteService(id: UUID) {
        if let snapshot = snapshots.first(where: { $0.id == id }) {
            self.servicePendingDeletion = snapshot
        }
    }

    public func confirmDeletePendingService(workspaceID: UUID) {
        guard let pending = servicePendingDeletion else { return }
        let id = pending.id
        self.servicePendingDeletion = nil
        deleteService(id: id, workspaceID: workspaceID)
    }

    public func deleteService(id: UUID, workspaceID: UUID) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            snapshots.removeAll(where: { $0.id == id })
            runtimeStates.removeValue(forKey: id)
            if selectedServiceID == id {
                selectedServiceID = nil
                isInspectorPresented = false
            }
        }

        Task {
            do {
                try await serviceRepository.deleteService(id: id)
                NotificationCenter.default.post(name: .kumaServiceDeleted, object: id)
            } catch {
                Self.logger.error("Failed to delete service \(id): \(error)")
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
