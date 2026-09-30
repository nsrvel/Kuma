import SwiftUI

/// Form stack container for Service Inspector's single unified scrollable configuration view.
public struct InspectorConfigFormStack: View {
    public let serviceID: UUID
    public let isLocked: Bool
    public let isRunning: Bool
    public let inspectorVM: ServiceInspectorViewModel
    public let service: Service

    public init(
        serviceID: UUID,
        isLocked: Bool,
        isRunning: Bool,
        inspectorVM: ServiceInspectorViewModel,
        service: Service
    ) {
        self.serviceID = serviceID
        self.isLocked = isLocked
        self.isRunning = isRunning
        self.inspectorVM = inspectorVM
        self.service = service
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Status Banner with Live Logs CTA
                InspectorRunningBanner(
                    runtime: ServiceRuntimeState(executionState: inspectorVM.executionState),
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
                        provider: Binding(
                            get: { inspectorVM.providers[activeIndex] },
                            set: { inspectorVM.providers[activeIndex] = $0 }
                        ),
                        ports: Binding(
                            get: { inspectorVM.draftPorts },
                            set: { inspectorVM.draftPorts = $0 }
                        ),
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
    }
}
