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
                // Zone 1: Native macOS Status Header
                InspectorStatusHeader(
                    service: service,
                    provider: inspectorVM.activeProvider,
                    runtime: .idle,
                    onToggle: {
                        // Decoupled: Placeholder toggle for future precision execution engine
                        NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
                    },
                    onToggleStar: {
                        Task {
                            _ = try? await ServiceRepository().toggleStarred(serviceID: serviceID)
                            NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
                        }
                    }
                )

                Divider()
                    .padding(.horizontal, KumaSpacing.lg)

                // Single Unified Scrollable Inspector View
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
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
                            icon: service.isDisabled ? "lock.fill" : "info.circle",
                            subtitle: "Service name and purpose"
                        )
                        .disabled(service.isDisabled)

                        // 2. Providers Section (Selector + Inline Add/Edit)
                        ServiceProvidersSectionView(
                            serviceID: serviceID,
                            providers: inspectorVM.providers,
                            activeProviderID: inspectorVM.activeProviderID,
                            isLocked: service.isDisabled,
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
                                isLocked: service.isDisabled,
                                onFieldChanged: {
                                    inspectorVM.scheduleAutoSave()
                                }
                            )
                            .disabled(service.isDisabled)
                        }

                        // 4. Options Section (Disable, Delete Service)
                        InspectorOptionsSection(
                            isDisabled: Binding(
                                get: { inspectorVM.service?.isDisabled ?? false },
                                set: { newValue in
                                    inspectorVM.toggleDisabled(newValue)
                                }
                            ),
                            isRunning: false,
                            isEditing: true,
                            onDelete: {
                                inspectorVM.showDeleteConfirmation = true
                            }
                        )
                    }
                .padding(KumaSpacing.lg)
                }
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
