import SwiftUI

public struct ServiceInspectorView: View {
    public let serviceID: UUID
    public let workspaceID: UUID
    @Bindable var viewModel: ServicesDeckViewModel
    @State private var inspectorVM: ServiceInspectorViewModel

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        viewModel: ServicesDeckViewModel,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        self.viewModel = viewModel
        let snap = viewModel.snapshots.first(where: { $0.id == serviceID })
        _inspectorVM = State(initialValue: ServiceInspectorViewModel(
            serviceID: serviceID,
            workspaceID: workspaceID,
            initialCategory: snap?.providerCategory,
            initialName: snap?.name ?? "",
            serviceRepository: serviceRepository
        ))
    }

    private var snapshot: ServiceCardSnapshot? {
        viewModel.snapshots.first(where: { $0.id == serviceID })
    }

    private var runtime: ServiceRuntimeState {
        viewModel.runtimeStates[serviceID] ?? ServiceRuntimeState()
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let snapshot {
                // Zone 1: Status Header (Fixed Top)
                InspectorStatusHeader(
                    snapshot: snapshot,
                    runtime: runtime,
                    hasChanges: inspectorVM.hasPendingChanges,
                    isSaving: inspectorVM.isSaving,
                    onToggle: { viewModel.toggleService(id: serviceID) },
                    onToggleStar: { viewModel.toggleStarred(id: serviceID, workspaceID: workspaceID) },
                    onSave: {
                        inspectorVM.saveChanges {
                            viewModel.loadWorkspace(workspaceID: workspaceID)
                        }
                    },
                    onCancel: { inspectorVM.cancelChanges() }
                )

                Divider()
                    .padding(.horizontal, KumaSpacing.lg)

                // Single Unified Scrollable Inspector View
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. General Identification Form
                        ServiceGeneralSettingsView(
                            name: $inspectorVM.generalDraft.name,
                            serviceDescription: $inspectorVM.generalDraft.description,
                            placeholder: "Postgres DB",
                            icon: runtime.status.isOperational ? "lock.fill" : "info.circle",
                            subtitle: "Service name and purpose"
                        )
                        .disabled(runtime.status.isOperational)

                        // 2. Providers Section (Selector + Inline Add/Edit)
                        ServiceProvidersSectionView(
                            serviceID: serviceID,
                            providers: inspectorVM.providers,
                            activeProviderID: $inspectorVM.activeProviderID,
                            isEditing: true,
                            isRunning: runtime.status.isOperational,
                            onSelectProvider: { newID in
                                inspectorVM.switchProvider(to: newID) {
                                    viewModel.loadWorkspace(workspaceID: workspaceID)
                                }
                            },
                            onSaveProvider: { provider in
                                inspectorVM.saveProviderDirectly(provider) {
                                    viewModel.loadWorkspace(workspaceID: workspaceID)
                                }
                            },
                            onDeleteProvider: { provider in
                                inspectorVM.deleteProvider(provider) {
                                    viewModel.loadWorkspace(workspaceID: workspaceID)
                                }
                            }
                        )

                        // 3. Active Provider Configuration Form (Directly Inline)
                        InspectorFormSections(
                            providerCategory: inspectorVM.activeCategory,
                            isEditing: true,
                            kubeConfigVM: inspectorVM.kubeConfigVM,
                            kubeDraft: $inspectorVM.kubeDraft,
                            dockerDraft: $inspectorVM.dockerDraft,
                            podmanDraft: $inspectorVM.podmanDraft,
                            shellDraft: $inspectorVM.shellDraft,
                            sshDraft: $inspectorVM.sshDraft,
                            healthCheckDraft: $inspectorVM.healthCheckDraft,
                            tunnelDraft: $inspectorVM.tunnelDraft,
                            monitorDraft: $inspectorVM.monitorDraft,
                            ports: $inspectorVM.draftPorts
                        )
                        .disabled(runtime.status.isOperational)

                        // 4. Options Section (Disable, Delete Service)
                        InspectorOptionsSection(
                            isDisabled: Binding(
                                get: { inspectorVM.generalDraft.isDisabled },
                                set: { newValue in
                                    inspectorVM.generalDraft.isDisabled = newValue
                                    inspectorVM.toggleDisableDirectly(newValue) {
                                        viewModel.loadWorkspace(workspaceID: workspaceID)
                                    }
                                }
                            ),
                            isRunning: runtime.status.isOperational,
                            isEditing: true,
                            onDelete: {
                                inspectorVM.showDeleteConfirmation = true
                            }
                        )
                    }
                    .padding(KumaSpacing.lg)
                }
                .animation(.easeInOut(duration: 0.2), value: inspectorVM.activeCategory)
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service to view configuration details."
                )
            }
        }
        .task(id: serviceID) {
            await inspectorVM.loadServiceDetails()
        }
        .onChange(of: inspectorVM.activeProviderID) { _, newActiveID in
            inspectorVM.populateActiveProviderFields(for: newActiveID)
        }
        .confirmationDialog(
            "Delete Service?",
            isPresented: $inspectorVM.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Service", role: .destructive) {
                inspectorVM.deleteService {
                    viewModel.loadWorkspace(workspaceID: workspaceID)
                    viewModel.selectedServiceID = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. '\(inspectorVM.generalDraft.name)' and all associated runner configurations will be permanently deleted.")
        }
    }
}
