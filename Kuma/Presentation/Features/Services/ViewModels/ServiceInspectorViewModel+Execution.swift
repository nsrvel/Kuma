import Foundation
import os

extension ServiceInspectorViewModel {
    public func toggleRunning() {
        Task {
            let wasRunning = isRunning
            if wasRunning {
                stateStore?.setExecutionState(.stopping, for: serviceID)
                ServiceStateNotification.post(serviceID: serviceID, state: .stopping)
                await ServiceExecutionEngine.shared.stop(serviceID: serviceID)
                stateStore?.setExecutionState(.idle, for: serviceID)
                ServiceStateNotification.post(serviceID: serviceID, state: .stopped)
            } else {
                stateStore?.setExecutionState(.starting, for: serviceID)
                ServiceStateNotification.post(serviceID: serviceID, state: .starting)
                do {
                    try await ServiceExecutionEngine.shared.start(serviceID: serviceID)
                    if let proc = await ProcessRegistry.shared.getSnapshot(serviceID: serviceID) {
                        stateStore?.setExecutionState(.running(pid: proc.pid), for: serviceID)
                    } else {
                        stateStore?.setExecutionState(.running(pid: 0), for: serviceID)
                    }
                    let pid = await ProcessRegistry.shared.getSnapshot(serviceID: serviceID)?.pid ?? 0
                    ServiceStateNotification.post(serviceID: serviceID, state: .running, pid: pid)
                } catch {
                    Self.logger.error("Failed to start service \(self.serviceID): \(error.localizedDescription)")
                    stateStore?.setExecutionState(.crashed(exitCode: 1), for: serviceID)
                    ServiceStateNotification.post(serviceID: serviceID, state: .crashed, exitCode: 1)
                }
            }
            postUpdatedNotification()
        }
    }
}
