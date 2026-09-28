import SwiftUI

/// PERF-10: Keep runtime off `body` evaluation so `@Observable` store updates do not fan out to every row.
struct SyncedServiceRuntime: ViewModifier {
    let serviceID: UUID
    @Binding var runtime: ServiceRuntimeState
    @Environment(ServiceStateStore.self) private var serviceStateStore

    func body(content: Content) -> some View {
        content
            .onAppear { runtime = serviceStateStore.runtime(for: serviceID) }
            .onReceive(NotificationCenter.default.publisher(for: .kumaServiceStateChanged)) { note in
                guard note.object as? UUID == serviceID else { return }
                if let execState = ServiceStateNotification.executionState(
                    from: note.userInfo,
                    existing: serviceStateStore.state(for: serviceID)
                ) {
                    runtime = ServiceRuntimeState(executionState: execState)
                } else {
                    runtime = serviceStateStore.runtime(for: serviceID)
                }
            }
    }
}

extension View {
    func syncingServiceRuntime(serviceID: UUID, runtime: Binding<ServiceRuntimeState>) -> some View {
        modifier(SyncedServiceRuntime(serviceID: serviceID, runtime: runtime))
    }
}
