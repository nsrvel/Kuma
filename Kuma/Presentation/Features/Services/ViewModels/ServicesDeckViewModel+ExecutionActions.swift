import Foundation
import os

extension ServicesDeckViewModel {
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
}
