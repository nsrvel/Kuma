import SwiftUI

extension ServicesDeckView {
    @ViewBuilder
    func applyDeckNotificationHandlers<Content: View>(
        to content: Content,
        workspaceID: UUID
    ) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .kumaServiceUpdated)) { notif in
                if let sID = notif.object as? UUID {
                    Task { await viewModel.refreshSingleServiceSnapshot(id: sID) }
                } else {
                    viewModel.loadWorkspace(workspaceID: workspaceID)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .kumaServiceCreated)) { notif in
                if let sID = notif.object as? UUID {
                    Task { await viewModel.refreshSingleServiceSnapshot(id: sID) }
                } else {
                    viewModel.loadWorkspace(workspaceID: workspaceID)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .kumaServiceStateChanged)) { notif in
                guard let serviceID = notif.object as? UUID,
                      let state = notif.userInfo?["state"] as? ServiceState else { return }
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
            .onReceive(NotificationCenter.default.publisher(for: .kumaServiceDeleted)) { notif in
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
            .onReceive(NotificationCenter.default.publisher(for: .kumaGroupsUpdated)) { _ in
                viewModel.loadWorkspace(workspaceID: workspaceID)
            }
            .onReceive(NotificationCenter.default.publisher(for: .kumaFocusSearch)) { _ in
                isSearching = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .kumaExportWorkspace)) { _ in
                exportCurrentWorkspace()
            }
            .onReceive(NotificationCenter.default.publisher(for: .kumaImportWorkspace)) { _ in
                promptImportFile()
            }
    }
}
