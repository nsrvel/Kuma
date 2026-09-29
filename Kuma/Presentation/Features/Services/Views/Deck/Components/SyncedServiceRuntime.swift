import SwiftUI

/// PERF-10: Keep runtime off `body` evaluation so `@Observable` store updates do not fan out to every row.
struct SyncedServiceRuntime: ViewModifier {
    let serviceID: UUID
    @Binding var runtime: ServiceRuntimeState
    @Environment(ServiceStateStore.self) private var serviceStateStore

    func body(content: Content) -> some View {
        content
            .onAppear { syncRuntime() }
            .onChange(of: serviceStateStore.executionStates[serviceID]) { _, _ in
                syncRuntime()
            }
    }

    private func syncRuntime() {
        runtime = serviceStateStore.runtime(for: serviceID)
    }
}

extension View {
    func syncingServiceRuntime(serviceID: UUID, runtime: Binding<ServiceRuntimeState>) -> some View {
        modifier(SyncedServiceRuntime(serviceID: serviceID, runtime: runtime))
    }
}
