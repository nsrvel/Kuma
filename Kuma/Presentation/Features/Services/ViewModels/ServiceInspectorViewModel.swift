import Foundation
import Observation
import os

@Observable
@MainActor
public final class ServiceInspectorViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ServiceInspectorViewModel")

    public let serviceID: UUID
    public let workspaceID: UUID
    private let serviceRepository: any ServiceRepositoryProtocol

    // MARK: - Raw Loaded Models
    public var service: Service? = nil
    public var providers: [Provider] = []
    public var activeProviderID: UUID? = nil

    // MARK: - Grouped Form Drafts
    public var generalDraft = ServiceGeneralDraft()
    public var kubeDraft = ServiceKubernetesDraft()
    public var kubeConfigVM: KubeConfigViewModel? = nil
    public var dockerDraft = ServiceComposeDraft()
    public var podmanDraft = ServiceComposeDraft()
    public var shellDraft = ServiceShellDraft()
    public var sshDraft = ServiceSSHDraft()
    public var healthCheckDraft = ServiceHealthCheckDraft()
    public var tunnelDraft = ServiceTunnelDraft()
    public var monitorDraft = ServiceProcessMonitorDraft()
    public var draftPorts: [KumaPortMappingItem] = []

    // MARK: - UI & Dialog States
    public var isLoadingData: Bool = false
    public var isSaving: Bool = false
    public var showDeleteConfirmation: Bool = false
    public var showDeleteProviderConfirmation: Bool = false

    private let initialCategory: ProviderCategory?
    private var initialPorts: [KumaPortMappingItem] = []

    // MARK: - Computed Properties

    public var activeProvider: Provider? {
        if let activeProviderID {
            return providers.first(where: { $0.id == activeProviderID })
        }
        return providers.first
    }

    public var activeCategory: ProviderCategory {
        activeProvider?.type ?? initialCategory ?? .docker
    }

    public var hasPendingChanges: Bool {
        guard let srv = service else { return false }

        if generalDraft.name.trimmingCharacters(in: .whitespacesAndNewlines) != srv.name { return true }
        if generalDraft.description.trimmingCharacters(in: .whitespacesAndNewlines) != (srv.description ?? "") { return true }

        if let p = activeProvider {
            switch p.type {
            case .kubernetes:
                let currentConfigID = kubeConfigVM?.selectedKubeConfigID ?? kubeDraft.configID
                if currentConfigID != p.kubeConfigID { return true }
                if kubeDraft.namespace != (p.kubeNamespace ?? "") { return true }
                if kubeDraft.context != (p.kubeContext ?? "") { return true }
                if kubeDraft.targetName != (p.targetName ?? "") { return true }
                if kubeDraft.targetType.rawValue != (p.kubeTargetType ?? "") { return true }
                if kubeDraft.usePattern != (p.usePattern ?? true) { return true }
            case .docker:
                if dockerDraft.yamlConfig != (p.yamlConfig ?? "") { return true }
                if dockerDraft.initialScript != (p.initialScript ?? "") { return true }
            case .podman:
                if podmanDraft.yamlConfig != (p.yamlConfig ?? "") { return true }
                if podmanDraft.initialScript != (p.initialScript ?? "") { return true }
            case .shell:
                if shellDraft.runCommand != (p.runCommand ?? "") { return true }
                if shellDraft.workingDirectory != (p.workingDirectory ?? "") { return true }
            case .ssh:
                if sshDraft.host != (p.sshHost ?? "") { return true }
                if sshDraft.user != (p.sshUser ?? "") { return true }
                let currentPort = p.sshPort != nil ? "\(p.sshPort!)" : "22"
                if sshDraft.port != currentPort { return true }
            case .httpCheck:
                if healthCheckDraft.url != (p.httpCheckUrl ?? "") { return true }
                if healthCheckDraft.interval.rawValue != (p.httpCheckInterval ?? 10) { return true }
            case .tunnel:
                if tunnelDraft.engine.rawValue != (p.tunnelType ?? "cloudflare") { return true }
                if tunnelDraft.targetUrl != (p.tunnelTargetUrl ?? "") { return true }
                if tunnelDraft.authToken != (p.ngrokAuthToken ?? "") { return true }
            case .processMonitor:
                if monitorDraft.processName != (p.monitorProcessName ?? "") { return true }
                if monitorDraft.interval.rawValue != (p.monitorInterval ?? 5) { return true }
            }
        }

        if draftPorts != initialPorts { return true }

        return false
    }

    // MARK: - Initializer

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        initialCategory: ProviderCategory? = nil,
        initialName: String = "",
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        self.initialCategory = initialCategory
        self.serviceRepository = serviceRepository
        self.generalDraft = ServiceGeneralDraft(name: initialName)

        // Pre-initialize KubeConfigViewModel if starting with Kubernetes category
        if initialCategory == .kubernetes {
            self.kubeConfigVM = KubeConfigViewModel()
        }
    }

    // MARK: - Data Loading

    public func loadServiceDetails() async {
        isLoadingData = true
        do {
            async let fetchService = serviceRepository.fetchService(id: serviceID)
            async let fetchProviders = serviceRepository.fetchProviders(forService: serviceID)
            async let fetchPorts = serviceRepository.fetchPortMappings(forService: serviceID)

            let (srv, provs, portList) = try await (fetchService, fetchProviders, fetchPorts)

            guard let srv else {
                isLoadingData = false
                return
            }

            self.service = srv
            self.providers = provs
            self.activeProviderID = srv.activeProviderID ?? provs.first?.id

            self.generalDraft = ServiceGeneralDraft(
                name: srv.name,
                description: srv.description ?? "",
                isDisabled: srv.isDisabled
            )

            self.draftPorts = portList.map {
                KumaPortMappingItem(id: $0.id, local: "\($0.localPort)", remote: "\($0.remotePort)")
            }
            self.initialPorts = self.draftPorts

            populateActiveProviderFields(for: self.activeProviderID)
            self.isLoadingData = false
        } catch {
            Self.logger.error("Failed to load service details for \(self.serviceID): \(error.localizedDescription)")
            self.isLoadingData = false
        }
    }

    public func cancelChanges() {
        guard let srv = service else { return }
        generalDraft = ServiceGeneralDraft(
            name: srv.name,
            description: srv.description ?? "",
            isDisabled: srv.isDisabled
        )
        draftPorts = initialPorts
        populateActiveProviderFields(for: activeProviderID)
    }

    public func populateActiveProviderFields(for providerID: UUID?) {
        guard let p = providers.first(where: { $0.id == providerID }) ?? providers.first else { return }

        if p.type == .kubernetes {
            if kubeConfigVM == nil {
                kubeConfigVM = KubeConfigViewModel()
            }
            kubeConfigVM?.selectedKubeConfigID = p.kubeConfigID ?? KubeConfig.defaultID
            kubeDraft = ServiceKubernetesDraft(
                configID: p.kubeConfigID,
                namespace: p.kubeNamespace ?? "",
                context: p.kubeContext ?? "",
                targetName: p.targetName ?? "",
                targetType: KubeTargetType(rawValue: p.kubeTargetType ?? "") ?? .pod,
                usePattern: p.usePattern ?? true
            )
        } else if p.type == .docker {
            dockerDraft = ServiceComposeDraft(
                yamlConfig: p.yamlConfig ?? "",
                initialScript: p.initialScript ?? ""
            )
        } else if p.type == .podman {
            podmanDraft = ServiceComposeDraft(
                yamlConfig: p.yamlConfig ?? "",
                initialScript: p.initialScript ?? ""
            )
        } else if p.type == .shell {
            shellDraft = ServiceShellDraft(
                runCommand: p.runCommand ?? "",
                workingDirectory: p.workingDirectory ?? ""
            )
        } else if p.type == .ssh {
            sshDraft = ServiceSSHDraft(
                host: p.sshHost ?? "",
                user: p.sshUser ?? "",
                port: p.sshPort != nil ? "\(p.sshPort!)" : "22"
            )
        } else if p.type == .httpCheck {
            healthCheckDraft = ServiceHealthCheckDraft(
                url: p.httpCheckUrl ?? "",
                interval: HealthCheckIntervalOption(rawValue: p.httpCheckInterval ?? 5) ?? .fast
            )
        } else if p.type == .tunnel {
            tunnelDraft = ServiceTunnelDraft(
                engine: TunnelEngineOption(rawValue: p.tunnelType ?? "cloudflare") ?? .cloudflare,
                targetUrl: p.tunnelTargetUrl ?? "http://localhost:3000",
                authToken: p.ngrokAuthToken ?? ""
            )
        } else if p.type == .processMonitor {
            monitorDraft = ServiceProcessMonitorDraft(
                processName: p.monitorProcessName ?? "",
                interval: HealthCheckIntervalOption(rawValue: p.monitorInterval ?? 5) ?? .fast
            )
        }
    }

    // MARK: - Actions & Persistence

    public func toggleDisableDirectly(_ disabled: Bool, onWorkspaceReload: @escaping () -> Void) {
        guard var srv = service else { return }
        srv.isDisabled = disabled
        srv.updatedAt = Date()
        self.service = srv
        Task {
            do {
                try await serviceRepository.updateService(srv)
                onWorkspaceReload()
            } catch {
                Self.logger.error("Failed to toggle disable service \(srv.id): \(error.localizedDescription)")
            }
        }
    }

    public func switchProvider(to providerID: UUID, onWorkspaceReload: @escaping () -> Void) {
        activeProviderID = providerID
        guard var srv = service else { return }
        srv.activeProviderID = providerID
        srv.updatedAt = Date()
        self.service = srv
        populateActiveProviderFields(for: providerID)
        Task {
            do {
                try await serviceRepository.updateService(srv)
                onWorkspaceReload()
            } catch {
                Self.logger.error("Failed to switch active provider for service \(srv.id): \(error.localizedDescription)")
            }
        }
    }

    public func saveProviderDirectly(_ provider: Provider, onWorkspaceReload: @escaping () -> Void) {
        Task {
            do {
                if providers.contains(where: { $0.id == provider.id }) {
                    try await serviceRepository.updateProvider(provider)
                } else {
                    try await serviceRepository.insertProvider(provider)
                }
                await loadServiceDetails()
                onWorkspaceReload()
            } catch {
                Self.logger.error("Failed to save provider \(provider.id): \(error.localizedDescription)")
            }
        }
    }

    public func deleteProvider(_ provider: Provider, onWorkspaceReload: @escaping () -> Void) {
        Task {
            do {
                try await serviceRepository.deleteProvider(id: provider.id)
                await loadServiceDetails()
                onWorkspaceReload()
            } catch {
                Self.logger.error("Failed to delete provider \(provider.id): \(error.localizedDescription)")
            }
        }
    }

    public func deleteService(onWorkspaceReload: @escaping () -> Void) {
        Task {
            do {
                try await serviceRepository.deleteService(id: serviceID)
                onWorkspaceReload()
            } catch {
                Self.logger.error("Failed to delete service \(self.serviceID): \(error.localizedDescription)")
            }
        }
    }

    public func saveChanges(onWorkspaceReload: @escaping () -> Void) {
        guard var srv = service else { return }
        isSaving = true

        srv.name = generalDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        srv.description = generalDraft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : generalDraft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        srv.isDisabled = generalDraft.isDisabled
        srv.activeProviderID = activeProviderID
        srv.updatedAt = Date()

        var updatedProvider = activeProvider ?? Provider(serviceID: serviceID, type: .docker)
        updatedProvider.updatedAt = Date()

        switch updatedProvider.type {
        case .kubernetes:
            updatedProvider.kubeConfigID = kubeConfigVM?.selectedKubeConfigID ?? kubeDraft.configID
            updatedProvider.kubeNamespace = kubeDraft.namespace.isEmpty ? nil : kubeDraft.namespace
            updatedProvider.kubeContext = kubeDraft.context.isEmpty ? nil : kubeDraft.context
            updatedProvider.targetName = kubeDraft.targetName.isEmpty ? nil : kubeDraft.targetName
            updatedProvider.kubeTargetType = kubeDraft.targetType.rawValue
            updatedProvider.usePattern = kubeDraft.usePattern
        case .docker:
            updatedProvider.yamlConfig = dockerDraft.yamlConfig
            updatedProvider.initialScript = dockerDraft.initialScript.isEmpty ? nil : dockerDraft.initialScript
        case .podman:
            updatedProvider.yamlConfig = podmanDraft.yamlConfig
            updatedProvider.initialScript = podmanDraft.initialScript.isEmpty ? nil : podmanDraft.initialScript
        case .shell:
            updatedProvider.runCommand = shellDraft.runCommand
            updatedProvider.workingDirectory = shellDraft.workingDirectory.isEmpty ? nil : shellDraft.workingDirectory
        case .ssh:
            updatedProvider.sshHost = sshDraft.host.isEmpty ? nil : sshDraft.host
            updatedProvider.sshUser = sshDraft.user.isEmpty ? nil : sshDraft.user
            updatedProvider.sshPort = Int(sshDraft.port) ?? 22
        case .httpCheck:
            updatedProvider.httpCheckUrl = healthCheckDraft.url
            updatedProvider.httpCheckInterval = healthCheckDraft.interval.rawValue
        case .tunnel:
            updatedProvider.tunnelType = tunnelDraft.engine.rawValue
            updatedProvider.tunnelTargetUrl = tunnelDraft.targetUrl
            updatedProvider.ngrokAuthToken = tunnelDraft.authToken.isEmpty ? nil : tunnelDraft.authToken
        case .processMonitor:
            updatedProvider.monitorProcessName = monitorDraft.processName
            updatedProvider.monitorInterval = monitorDraft.interval.rawValue
        }

        let realPorts = draftPorts.compactMap { item -> ServicePortMapping? in
            guard let local = Int(item.local), let remote = Int(item.remote), local > 0, remote > 0 else { return nil }
            return ServicePortMapping(id: item.id, serviceID: serviceID, localPort: local, remotePort: remote, protocolType: "TCP")
        }

        Task {
            do {
                try await serviceRepository.updateService(srv)
                try await serviceRepository.updateProvider(updatedProvider)
                try await serviceRepository.savePortMappings(realPorts, forService: serviceID)

                await MainActor.run {
                    self.service = srv
                    self.initialPorts = self.draftPorts
                    self.isSaving = false
                    onWorkspaceReload()
                }
            } catch {
                Self.logger.error("Failed to save changes for service \(self.serviceID): \(error.localizedDescription)")
                await MainActor.run {
                    self.isSaving = false
                }
            }
        }
    }
}
