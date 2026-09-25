import SwiftUI
import Observation
import os

@MainActor
@Observable
public final class ServicesDeckViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ServicesDeckViewModel")

    // MARK: - Filter Inputs (each triggers recompute on change)

    public var searchText: String = "" {
        didSet {
            if oldValue != searchText {
                searchDebounceTask?.cancel()
                searchDebounceTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    guard !Task.isCancelled, let self else { return }
                    self.recomputeFilteredSnapshots()
                }
            }
        }
    }
    private var searchDebounceTask: Task<Void, Never>? = nil
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

    public var canStartAll: Bool {
        bulkActionSnapshots.contains { !$0.isDisabled && !isOperational($0.id) }
    }

    public var canStopAll: Bool {
        bulkActionSnapshots.contains { isOperational($0.id) }
    }

    public func runtime(for id: UUID) -> ServiceRuntimeState {
        stateStore?.runtime(for: id) ?? .idle
    }

    private func isOperational(_ id: UUID) -> Bool {
        stateStore?.state(for: id).isOperational == true
    }

    /// Recompute filtered deck when execution state changes and filters depend on status.
    public func notifyExecutionStatesChanged() {
        if !selectedStatuses.isEmpty || sortBy == .status {
            recomputeFilteredSnapshots()
        }
    }

    /// Deck list scope for bulk start/stop (sidebar: All / Starred / Group + toolbar filters).
    private var bulkActionSnapshots: [ServiceCardSnapshot] {
        filteredSnapshots
    }

    // MARK: - Groups Data
    public var groups: [ServiceGroup] = []

    private let serviceRepository: any ServiceRepositoryProtocol
    private let groupRepository: any ServiceGroupRepositoryProtocol
    public var stateStore: ServiceStateStore?
    private let userDefaults: UserDefaults
    private var loadTask: Task<Void, Never>? = nil

    public init(
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository(),
        groupRepository: any ServiceGroupRepositoryProtocol = ServiceGroupRepository(),
        stateStore: ServiceStateStore? = nil,
        userDefaults: UserDefaults = .standard,
        isStarredOnly: Bool = false,
        filterGroupID: UUID? = nil
    ) {
        self.serviceRepository = serviceRepository
        self.groupRepository = groupRepository
        self.stateStore = stateStore
        self.userDefaults = userDefaults
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
                    let state = runtime(for: snapshot.id).status
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
                let priorityA: Int = a.isDisabled ? 5 : runtime(for: a.id).status.sortPriority
                let priorityB: Int = b.isDisabled ? 5 : runtime(for: b.id).status.sortPriority

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

    public func refreshGroups(workspaceID: UUID) async {
        do {
            groups = try await groupRepository.fetchAll(workspaceID: workspaceID)
        } catch {
            Self.logger.error("Failed to refresh groups for workspace \(workspaceID): \(error.localizedDescription)")
        }
    }

    public func loadWorkspaceAsync(workspaceID: UUID) async {
        do {
            async let loadedSnapshots = serviceRepository.fetchSnapshots(forWorkspace: workspaceID)
            async let loadedGroups = groupRepository.fetchAll(workspaceID: workspaceID)

            let (loaded, groups) = try await (loadedSnapshots, loadedGroups)
            guard !Task.isCancelled else { return }

            // Batch seed or refresh live runtime states from ProcessRegistry in 1 call (PERF-01)
            let serviceIDs = loaded.map(\.id)
            if let store = self.stateStore {
                await store.refreshProcessStates(for: serviceIDs)
            }

            let isFirstLoad = !self.hasInitialLoaded
            self.groups = groups
            self.snapshots = loaded
            self.hasInitialLoaded = true

            // Auto-start services if enabled and there are saved active service IDs from previous session
            if isFirstLoad && KumaSettingsKey.bool(forKey: KumaSettingsKey.autoResumeServices, defaultValue: false, defaults: self.userDefaults) {
                resumeServicesIfNeeded(loadedSnapshots: loaded)
            }
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error("Failed to load workspace \(workspaceID): \(error.localizedDescription)")
            self.snapshots = []
            self.hasInitialLoaded = true
        }
    }

    private func resumeServicesIfNeeded(loadedSnapshots: [ServiceCardSnapshot]) {
        guard let savedStrings = userDefaults.stringArray(forKey: KumaSettingsKey.activeServiceIDsBeforeQuit),
              !savedStrings.isEmpty else { return }

        let savedUUIDs = Set(savedStrings.compactMap(UUID.init))
        let candidates = loadedSnapshots.filter { !($0.isDisabled) && savedUUIDs.contains($0.id) }
        guard !candidates.isEmpty else { return }

        // Remove matched IDs from saved list so they aren't restarted repeatedly
        let remaining = savedUUIDs.subtracting(candidates.map(\.id))
        userDefaults.set(remaining.map(\.uuidString), forKey: KumaSettingsKey.activeServiceIDsBeforeQuit)

        Task {
            // Gentle stagger between auto-started services
            for snapshot in candidates {
                guard !isOperational(snapshot.id) else { continue }
                stateStore?.setExecutionState(.starting, for: snapshot.id)
                NotificationCenter.default.post(
                    name: .kumaServiceStateChanged,
                    object: snapshot.id,
                    userInfo: ["state": ServiceState.starting]
                )
                do {
                    try await ServiceExecutionEngine.shared.start(serviceID: snapshot.id)
                    let pid = await ProcessRegistry.shared.getSnapshot(serviceID: snapshot.id)?.pid ?? 0
                    stateStore?.setExecutionState(.running(pid: pid), for: snapshot.id)
                    NotificationCenter.default.post(
                        name: .kumaServiceStateChanged,
                        object: snapshot.id,
                        userInfo: ["state": ServiceState.running]
                    )
                } catch {
                    Self.logger.error("Auto-start failed for '\(snapshot.name)': \(error.localizedDescription)")
                    stateStore?.setExecutionState(.crashed(exitCode: 1), for: snapshot.id)
                    NotificationCenter.default.post(
                        name: .kumaServiceStateChanged,
                        object: snapshot.id,
                        userInfo: ["state": ServiceState.crashed]
                    )
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    /// Granular single-service snapshot refresh to avoid full workspace reload (SYNC-03 / PERF-04)
    public func refreshSingleServiceSnapshot(id: UUID) async {
        do {
            if let updated = try await serviceRepository.fetchSnapshot(serviceID: id) {
                if let idx = snapshots.firstIndex(where: { $0.id == id }) {
                    snapshots[idx] = updated
                } else {
                    snapshots.append(updated)
                }
            } else {
                snapshots.removeAll(where: { $0.id == id })
            }
            if let store = stateStore {
                await store.refreshProcessStates(for: [id])
            }
        } catch {
            Self.logger.error("Failed to reload single service snapshot \(id): \(error.localizedDescription)")
        }
    }

    public func toggleService(id: UUID) {
        Task {
            await toggleServiceAsync(id: id)
        }
    }

    public func toggleServiceAsync(id: UUID) async {
        let wasRunning = isOperational(id)

        if wasRunning {
            stateStore?.setExecutionState(.stopping, for: id)
            await ServiceExecutionEngine.shared.stop(serviceID: id)
            stateStore?.setExecutionState(.idle, for: id)
        } else {
            stateStore?.setExecutionState(.starting, for: id)
            do {
                try await ServiceExecutionEngine.shared.start(serviceID: id)
                if let proc = await ProcessRegistry.shared.getSnapshot(serviceID: id) {
                    stateStore?.setExecutionState(.running(pid: proc.pid), for: id)
                } else {
                    stateStore?.setExecutionState(.running(pid: 0), for: id)
                }
            } catch {
                Self.logger.error("Failed to start service \(id): \(error.localizedDescription)")
                stateStore?.setExecutionState(.crashed(exitCode: 1), for: id)
            }
        }

        notifyExecutionStatesChanged()
    }

    public func startAllServices() {
        Task {
            let targetSnapshots = bulkActionSnapshots.filter { snapshot in
                !snapshot.isDisabled && !isOperational(snapshot.id)
            }

            for snapshot in targetSnapshots {
                guard !isOperational(snapshot.id) else { continue }

                stateStore?.setExecutionState(.starting, for: snapshot.id)
                do {
                    try await ServiceExecutionEngine.shared.start(serviceID: snapshot.id)
                    let pid = await ProcessRegistry.shared.getSnapshot(serviceID: snapshot.id)?.pid ?? 0
                    stateStore?.setExecutionState(.running(pid: pid), for: snapshot.id)
                } catch {
                    Self.logger.error("Failed to start service \(snapshot.name): \(error.localizedDescription)")
                    stateStore?.setExecutionState(.crashed(exitCode: 1), for: snapshot.id)
                }

                try? await Task.sleep(nanoseconds: 150_000_000)
            }

            notifyExecutionStatesChanged()
        }
    }

    public func stopAllServices() {
        Task {
            let runningIDs = bulkActionSnapshots.map(\.id).filter { isOperational($0) }

            for id in runningIDs {
                stateStore?.setExecutionState(.stopping, for: id)
            }

            for id in runningIDs {
                await ServiceExecutionEngine.shared.stop(serviceID: id)
                stateStore?.setExecutionState(.idle, for: id)
            }

            notifyExecutionStatesChanged()
        }
    }

    public func restartService(id: UUID) {
        Task {
            stateStore?.setExecutionState(.stopping, for: id)
            await ServiceExecutionEngine.shared.stop(serviceID: id)
            try? await Task.sleep(nanoseconds: 300_000_000)

            stateStore?.setExecutionState(.starting, for: id)
            do {
                try await ServiceExecutionEngine.shared.start(serviceID: id)
                let pid = await ProcessRegistry.shared.getSnapshot(serviceID: id)?.pid ?? 0
                stateStore?.setExecutionState(.running(pid: pid), for: id)
            } catch {
                Self.logger.error("Failed to restart service \(id): \(error.localizedDescription)")
                stateStore?.setExecutionState(.crashed(exitCode: 1), for: id)
            }

            notifyExecutionStatesChanged()
        }
    }

    public func toggleStarred(id: UUID, workspaceID: UUID) {
        KumaHapticManager.shared.tap()
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
            stateStore?.setExecutionState(.idle, for: id)
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
        let isCurrentlyRunning = isOperational(serviceID)

        Task {
            do {
                if isCurrentlyRunning {
                    stateStore?.setExecutionState(.stopping, for: serviceID)
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
                        stateStore?.setExecutionState(.starting, for: serviceID)
                        try await ServiceExecutionEngine.shared.start(serviceID: serviceID)
                        let pid = await ProcessRegistry.shared.getSnapshot(serviceID: serviceID)?.pid ?? 0
                        stateStore?.setExecutionState(.running(pid: pid), for: serviceID)
                    }
                }
            } catch {
                Self.logger.error("Failed to switch provider for service \(serviceID): \(error)")
                stateStore?.setExecutionState(.crashed(exitCode: 1), for: serviceID)
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
            stateStore?.removeService(id)
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

    public func selectService(_ id: UUID?) {
        self.selectedServiceID = id
        self.isInspectorPresented = (id != nil)
    }

}
