import Foundation
import os

extension ServiceInspectorViewModel {
    public func toggleRunning() {
        Task {
            let wasRunning = isRunning
            if wasRunning {
                stateStore?.setExecutionState(.stopping, for: serviceID)
                await ServiceExecutionEngine.shared.stop(serviceID: serviceID)
                stateStore?.setExecutionState(.idle, for: serviceID)
            } else {
                stateStore?.setExecutionState(.starting, for: serviceID)
                do {
                    try await ServiceExecutionEngine.shared.start(serviceID: serviceID)
                    if let proc = await ProcessRegistry.shared.getSnapshot(serviceID: serviceID) {
                        stateStore?.setExecutionState(.running(pid: proc.pid), for: serviceID)
                    } else {
                        stateStore?.setExecutionState(.running(pid: 0), for: serviceID)
                    }
                } catch {
                    Self.logger.error("Failed to start service \(self.serviceID): \(error.localizedDescription)")
                    stateStore?.setExecutionState(.crashed(exitCode: 1), for: serviceID)
                }
            }
            postUpdatedNotification()
        }
    }
}
