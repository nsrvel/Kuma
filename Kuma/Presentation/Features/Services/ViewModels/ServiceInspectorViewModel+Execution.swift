import Foundation
import os

extension ServiceInspectorViewModel {
    public func toggleRunning() {
        if isRunning {
            stateStore?.setExecutionState(.stopping, for: serviceID)
            let sid = serviceID
            let store = stateStore
            Task.detached(priority: .userInitiated) {
                await ServiceStopSupport.stopOffMainActor(serviceID: sid, stateStore: store)
                await MainActor.run {
                    KumaServiceNotification.postServiceUpdated(
                        serviceID: sid,
                        source: KumaServiceNotification.sourceInspector
                    )
                }
            }
            return
        }
        Task {
            stateStore?.setExecutionState(.starting, for: serviceID)
            do {
                try await ServiceExecutionEngine.shared.start(serviceID: serviceID)
                await ServiceExecutionStateSync.applyAfterSuccessfulStart(
                    serviceID: serviceID,
                    stateStore: stateStore
                )
            } catch {
                Self.logger.error("Failed to start service \(self.serviceID): \(error.localizedDescription)")
                stateStore?.setExecutionState(.crashed(exitCode: 1), for: serviceID)
            }
            postUpdatedNotification()
        }
    }
}
