import Foundation
import os

extension ServiceInspectorViewModel {
    public func toggleRunning() {
        if isRunning {
            stateStore?.setExecutionState(.stopping, for: serviceID, publish: false)
            let sid = serviceID
            let store = stateStore
            Task.detached(priority: .userInitiated) { [weak self] in
                await ServiceStopSupport.stopOffMainActor(serviceID: sid, stateStore: store)
                await MainActor.run {
                    self?.postUpdatedNotification()
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
