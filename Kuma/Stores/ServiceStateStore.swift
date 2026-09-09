import Foundation
import Observation
import os

/// Central reactive bridge and single source of truth for service execution states across Kuma.
/// Shared by both ServicesDeckView and ServiceInspectorView to guarantee 100% synchronized state
/// without redundant database roundtrips or optimistic divergence.
@MainActor
@Observable
public final class ServiceStateStore {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ServiceStateStore")

    /// Single source of truth for service execution states
    public private(set) var executionStates: [UUID: ServiceExecutionState] = [:]

    private let processRegistry: ProcessRegistry

    public init(processRegistry: ProcessRegistry = .shared) {
        self.processRegistry = processRegistry
    }

    /// Fast O(1) state lookup with graceful fallback to .idle
    public func state(for serviceID: UUID) -> ServiceExecutionState {
        executionStates[serviceID] ?? .idle
    }

    /// Fast O(1) runtime wrapper for backwards compatibility with subviews
    public func runtime(for serviceID: UUID) -> ServiceRuntimeState {
        ServiceRuntimeState(executionState: state(for: serviceID))
    }

    /// IDs of services currently in an operational state (running or starting)
    public var activeServiceIDs: [UUID] {
        executionStates.compactMap { id, state in
            state.isOperational ? id : nil
        }
    }

    /// Updates execution state for a specific service directly (e.g. from notifications or user actions)
    public func setExecutionState(_ state: ServiceExecutionState, for serviceID: UUID) {
        if executionStates[serviceID] != state {
            executionStates[serviceID] = state
        }
    }

    /// Batch refreshes process states for an array of services via a single actor crossing
    public func refreshProcessStates(for serviceIDs: [UUID]) async {
        guard !serviceIDs.isEmpty else { return }
        let currentProcessStates = await processRegistry.runningStates(for: serviceIDs)

        for (id, state) in currentProcessStates {
            let existing = executionStates[id] ?? .idle
            // Don't overwrite an in-flight .starting or .stopping transition with background snapshot
            if existing == .starting && state == .idle {
                continue
            }
            if existing == .stopping && state.isOperational {
                continue
            }
            executionStates[id] = state
        }
    }

    /// Cleans up state when a service is deleted
    public func removeService(_ serviceID: UUID) {
        executionStates.removeValue(forKey: serviceID)
    }

    /// Resets all execution states (e.g. on workspace switch)
    public func removeAll() {
        executionStates.removeAll()
    }
}
