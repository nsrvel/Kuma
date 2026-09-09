import SwiftUI

public struct ServiceInspectorView: View {
    public let serviceID: UUID
    public let workspaceID: UUID
    @State private var inspectorVM: ServiceInspectorViewModel
    @Environment(ServiceStateStore.self) var serviceStateStore

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository(),
        stateStore: ServiceStateStore? = nil
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        _inspectorVM = State(initialValue: ServiceInspectorViewModel(
            serviceID: serviceID,
            workspaceID: workspaceID,
            serviceRepository: serviceRepository,
            stateStore: stateStore
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let service = inspectorVM.service {
                let isRunning = inspectorVM.isRunning
                let isLocked = service.isDisabled || isRunning

                let isViewingLogs = inspectorVM.isViewingLogs

                // Zone 1: Native macOS Status Header (Icon turns into Back button when viewing logs)
                InspectorStatusHeader(
                    service: service,
                    provider: inspectorVM.activeProvider,
                    runtime: ServiceRuntimeState(executionState: inspectorVM.executionState),
                    isViewingLogs: isViewingLogs,
                    onToggle: {
                        inspectorVM.toggleRunning()
                    },
                    onToggleStar: {
                        inspectorVM.toggleStarred()
                    },
                    onBack: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            inspectorVM.isViewingLogs = false
                        }
                    }
                )

                Divider()
                    .padding(.horizontal, KumaSpacing.lg)

                Group {
                    if isViewingLogs {
                        // Dedicated Full-Height Seamless Live Terminal Viewport
                        InspectorLiveConsoleView(
                            serviceID: service.id,
                            serviceName: service.name,
                            isRunning: isRunning
                        )
                        .padding(.vertical, 4)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        ))
                    } else {
                        InspectorConfigFormStack(
                            serviceID: serviceID,
                            isLocked: isLocked,
                            isRunning: isRunning,
                            inspectorVM: inspectorVM,
                            service: service
                        )
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isViewingLogs)
                .animation(.easeInOut(duration: 0.18), value: isRunning)
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service to view configuration details."
                )
            }
        }
        .task(id: serviceID) {
            inspectorVM.stateStore = serviceStateStore
            await inspectorVM.loadService(id: serviceID)
        }
        .task(id: serviceID) {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await notif in NotificationCenter.default.notifications(named: .kumaServiceStateChanged) {
                        if let changedID = notif.object as? UUID, changedID == serviceID, let state = notif.userInfo?["state"] as? ServiceState {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                inspectorVM.isRunning = state.isOperational
                            }
                        }
                    }
                }
                group.addTask {
                    for await notif in NotificationCenter.default.notifications(named: .kumaServiceUpdated) {
                        if notif.userInfo?["source"] as? String == "inspector" {
                            continue
                        }
                        if let changedID = notif.object as? UUID, changedID == serviceID {
                            await inspectorVM.loadService(id: serviceID)
                        }
                    }
                }
            }
        }
        .onDisappear {
            Task {
                await inspectorVM.flushPendingAutoSave()
            }
        }
        .confirmationDialog(
            "Delete Service?",
            isPresented: $inspectorVM.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Service", role: .destructive) {
                inspectorVM.deleteService()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. '\(inspectorVM.service?.name ?? "Service")' and all associated runner configurations will be permanently deleted.")
        }
    }
}
