import SwiftUI

extension ServicesDeckView {
    public func handleNotificationStream(workspaceID: UUID) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await notif in NotificationCenter.default.notifications(named: .kumaServiceUpdated) {
                    if let sID = notif.object as? UUID {
                        await viewModel.refreshSingleServiceSnapshot(id: sID)
                    } else {
                        viewModel.loadWorkspace(workspaceID: workspaceID)
                    }
                }
            }
            group.addTask {
                for await notif in NotificationCenter.default.notifications(named: .kumaServiceCreated) {
                    if let sID = notif.object as? UUID {
                        await viewModel.refreshSingleServiceSnapshot(id: sID)
                    } else {
                        viewModel.loadWorkspace(workspaceID: workspaceID)
                    }
                }
            }
            group.addTask {
                for await notif in NotificationCenter.default.notifications(named: .kumaServiceStateChanged) {
                    if let serviceID = notif.object as? UUID, let state = notif.userInfo?["state"] as? ServiceState {
                        let execState: ServiceExecutionState
                        switch state {
                        case .stopped: execState = .idle
                        case .starting: execState = .starting
                        case .running: execState = .running(pid: 0)
                        case .stopping: execState = .stopping
                        case .crashed: execState = .crashed(exitCode: 1)
                        }
                        serviceStateStore.setExecutionState(execState, for: serviceID)
                        viewModel.applyRuntimeDiff([serviceID: ServiceRuntimeState(status: state, isLoading: false)])
                    }
                }
            }
            group.addTask {
                for await notif in NotificationCenter.default.notifications(named: .kumaServiceDeleted) {
                    if let deletedID = notif.object as? UUID {
                        viewModel.snapshots.removeAll(where: { $0.id == deletedID })
                        viewModel.runtimeStates.removeValue(forKey: deletedID)
                        serviceStateStore.removeService(deletedID)
                        if viewModel.selectedServiceID == deletedID {
                            viewModel.selectedServiceID = nil
                            viewModel.isInspectorPresented = false
                        }
                    } else {
                        viewModel.loadWorkspace(workspaceID: workspaceID)
                    }
                }
            }
            group.addTask {
                for await _ in NotificationCenter.default.notifications(named: .kumaGroupsUpdated) {
                    viewModel.loadWorkspace(workspaceID: workspaceID)
                }
            }
            group.addTask {
                for await _ in NotificationCenter.default.notifications(named: .kumaFocusSearch) {
                    await MainActor.run { self.isSearching = true }
                }
            }
            group.addTask {
                for await _ in NotificationCenter.default.notifications(named: .kumaExportWorkspace) {
                    await MainActor.run { self.exportCurrentWorkspace() }
                }
            }
            group.addTask {
                for await _ in NotificationCenter.default.notifications(named: .kumaImportWorkspace) {
                    await MainActor.run { self.promptImportFile() }
                }
            }
        }
    }
}
