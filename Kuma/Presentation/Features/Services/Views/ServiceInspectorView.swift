import SwiftUI

public struct ServiceInspectorView: View {
    public let serviceID: UUID
    public let workspaceID: UUID
    @Bindable var viewModel: ServicesDeckViewModel

    @State private var inspectorData: InspectorData? = nil
    @State private var isLoadingData: Bool = false
    @State private var isEditSheetPresented: Bool = false

    private let serviceRepository: any ServiceRepositoryProtocol

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        viewModel: ServicesDeckViewModel,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        self.viewModel = viewModel
        self.serviceRepository = serviceRepository
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
                    onToggle: { viewModel.toggleService(id: serviceID) },
                    onToggleStar: { viewModel.toggleStarred(id: serviceID, workspaceID: workspaceID) },
                    onEdit: { isEditSheetPresented = true }
                )

                Divider()

                // Zone 2: Contextual Details (Scrollable Middle)
                if let inspectorData {
                    InspectorDetailRows(data: inspectorData)
                } else if isLoadingData {
                    VStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                }

                Divider()

                // Zone 3: Mini Live Logs Console (Fixed Bottom)
                InspectorMiniLogs(
                    serviceID: serviceID,
                    isRunning: runtime.status.isOperational
                )
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service to view configuration details and live logs."
                )
            }
        }
        .background(.regularMaterial)
        .task(id: serviceID) {
            await loadServiceDetails()
        }
    }

    private func loadServiceDetails() async {
        isLoadingData = true
        do {
            async let fetchService = serviceRepository.fetchService(id: serviceID)
            async let fetchProviders = serviceRepository.fetchProviders(forService: serviceID)
            async let fetchPorts = serviceRepository.fetchPortMappings(forService: serviceID)

            let (service, providers, ports) = try await (fetchService, fetchProviders, fetchPorts)

            guard let service else {
                isLoadingData = false
                return
            }

            let provider = providers.first(where: { $0.id == service.activeProviderID })
                ?? providers.first
                ?? Provider(serviceID: service.id, type: .docker)

            self.inspectorData = InspectorData(
                service: service,
                provider: provider,
                portMappings: ports
            )
        } catch {
            self.inspectorData = nil
        }
        isLoadingData = false
    }
}
