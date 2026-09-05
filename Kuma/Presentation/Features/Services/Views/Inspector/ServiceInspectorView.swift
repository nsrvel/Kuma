import SwiftUI

public struct ServiceInspectorView: View {
    public let serviceID: UUID
    public let workspaceID: UUID
    @State private var inspectorVM: ServiceInspectorViewModel

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        _inspectorVM = State(initialValue: ServiceInspectorViewModel(
            serviceID: serviceID,
            workspaceID: workspaceID,
            serviceRepository: serviceRepository
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
                    runtime: ServiceRuntimeState(status: isRunning ? .running : .stopped, isLoading: false),
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
                        // Single Unified Scrollable Configuration View
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                // Running State / Lock Banner with Live Logs CTA
                                InspectorRunningBanner(
                                    runtime: ServiceRuntimeState(status: isRunning ? .running : .stopped, isLoading: false),
                                    isDisabled: service.isDisabled,
                                    onViewLogs: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                            inspectorVM.isViewingLogs = true
                                        }
                                    }
                                )

                                // 1. General Identification Form
                                ServiceGeneralSettingsView(
                                    name: Binding(
                                        get: { inspectorVM.service?.name ?? "" },
                                        set: {
                                            inspectorVM.service?.name = $0
                                            inspectorVM.scheduleAutoSave()
                                        }
                                    ),
                                    serviceDescription: Binding(
                                        get: { inspectorVM.service?.description ?? "" },
                                        set: {
                                            inspectorVM.service?.description = $0.isEmpty ? nil : $0
                                            inspectorVM.scheduleAutoSave()
                                        }
                                    ),
                                    placeholder: "Postgres DB",
                                    icon: "info.circle",
                                    subtitle: "Service name and purpose"
                                )
                                .disabled(isLocked)

                                // 2. Providers Section (Selector + Inline Add/Edit)
                                ServiceProvidersSectionView(
                                    serviceID: serviceID,
                                    providers: inspectorVM.providers,
                                    activeProviderID: inspectorVM.activeProviderID,
                                    isLocked: isLocked,
                                    onSelectProvider: { newID in
                                        inspectorVM.switchProvider(to: newID)
                                    },
                                    onAddProvider: { newProvider in
                                        inspectorVM.addProvider(newProvider)
                                    },
                                    onUpdateProvider: { updatedProvider in
                                        inspectorVM.updateProviderDirectly(updatedProvider)
                                    },
                                    onDeleteProvider: { provider in
                                        inspectorVM.deleteProvider(provider)
                                    }
                                )

                                // 3. Active Provider Configuration Form
                                if let activeIndex = inspectorVM.providers.firstIndex(where: { $0.id == inspectorVM.activeProviderID }) {
                                    InspectorFormSections(
                                        provider: $inspectorVM.providers[activeIndex],
                                        ports: $inspectorVM.draftPorts,
                                        kubeConfigVM: inspectorVM.kubeConfigVM,
                                        isLocked: isLocked,
                                        onFieldChanged: {
                                            inspectorVM.scheduleAutoSave()
                                        }
                                    )
                                    .disabled(isLocked)
                                }

                                // 4. Options Section (Disable, Delete Service)
                                InspectorOptionsSection(
                                    isDisabled: Binding(
                                        get: { inspectorVM.service?.isDisabled ?? false },
                                        set: { newValue in
                                            inspectorVM.toggleDisabled(newValue)
                                        }
                                    ),
                                    isRunning: isRunning,
                                    isEditing: true,
                                    onDelete: {
                                        inspectorVM.showDeleteConfirmation = true
                                    }
                                )
                            }
                            .padding(KumaSpacing.lg)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isViewingLogs)
                .animation(.easeInOut(duration: 0.18), value: isRunning)
                .animation(.easeInOut(duration: 0.15), value: inspectorVM.activeCategory)
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service to view configuration details."
                )
            }
        }
        .task(id: serviceID) {
            await inspectorVM.loadService(id: serviceID)
        }
        .task(id: serviceID) {
            for await notif in NotificationCenter.default.notifications(named: .kumaServiceStateChanged) {
                if let changedID = notif.object as? UUID, changedID == serviceID, let state = notif.userInfo?["state"] as? ServiceState {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        inspectorVM.isRunning = state.isOperational
                    }
                }
            }
        }
        .onDisappear {
            inspectorVM.cancelAutoSave()
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
