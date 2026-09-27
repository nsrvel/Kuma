import Foundation

/// PERF-09: Skip execution-state fan-out when the machine is fully idle.
enum ServicesDeckRuntimeObservation {
    @MainActor
    static func shouldHandleExecutionStateNotifications(store: ServiceStateStore) -> Bool {
        if store.hasTransientExecutionStates { return true }
        return !ProcessRegistry.activeRunningServiceIDs.isEmpty
    }
}
