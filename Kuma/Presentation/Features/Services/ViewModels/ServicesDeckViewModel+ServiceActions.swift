import AppKit
import os
import SwiftUI

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

    public func toggleStarred(id: UUID, workspaceID: UUID) {
        KumaHapticManager.shared.tap()
        if let idx = snapshots.firstIndex(where: { $0.id == id }) {
            snapshots[idx] = snapshots[idx].toggling(starred: !snapshots[idx].isStarred)
        }

        Task {
            do {
                _ = try await serviceRepository.toggleStarred(serviceID: id)
                NotificationCenter.default.post(name: .kumaServiceUpdated, object: id)
            } catch {
                Self.logger.error("Failed to persist toggleStarred for service \(id): \(error.localizedDescription)")
                await loadWorkspaceAsync(workspaceID: workspaceID)
            }
        }
    }

    public func toggleDisabled(id: UUID, workspaceID: UUID) {
        guard let idx = snapshots.firstIndex(where: { $0.id == id }) else { return }
        let newDisabled = !snapshots[idx].isDisabled

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

        if newDisabled {
            stateStore?.setExecutionState(.idle, for: id)
        }

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
