import Foundation
import Observation
import os

@Observable
@MainActor
public final class ServiceInspectorViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ServiceInspectorViewModel")

    public private(set) var serviceID: UUID
    public let workspaceID: UUID
    private let serviceRepository: any ServiceRepositoryProtocol

    // MARK: - Single Source of Truth (Domain Entities)
    public var service: Service? = nil
    public var providers: [Provider] = []
    public var activeProviderID: UUID? = nil
    public var draftPorts: [KumaPortMappingItem] = []

    // MARK: - UI & State Flags
    public var isLoadingData: Bool = false
    public var showDeleteConfirmation: Bool = false
    public var showDeleteProviderConfirmation: Bool = false
    public var providerPendingDeletion: Provider? = nil

    // Kubernetes context helper (lazy initialization)
    public var kubeConfigVM: KubeConfigViewModel? = nil

    // Debounce task for continuous text inputs (instant auto-save)
    private var autoSaveTask: Task<Void, Never>? = nil

    // MARK: - Computed Helpers

    public var activeProvider: Provider? {
        if let activeProviderID {
            return providers.first(where: { $0.id == activeProviderID })
        }
        return providers.first
    }

    public var activeCategory: ProviderCategory {
        activeProvider?.type ?? .docker
    }

    // MARK: - Initializer

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        self.serviceRepository = serviceRepository
    }

    // MARK: - Data Loading

    public func loadService(id: UUID) async {
        self.serviceID = id
        do {
            async let fetchService = serviceRepository.fetchService(id: id)
            async let fetchProviders = serviceRepository.fetchProviders(forService: id)
            async let fetchPorts = serviceRepository.fetchPortMappings(forService: id)

            let (srv, provs, portList) = try await (fetchService, fetchProviders, fetchPorts)

            guard let srv, self.serviceID == id else { return }

            // In-place atomic update: values morph without destroying UI layout
            self.service = srv
            self.providers = provs
            self.activeProviderID = srv.activeProviderID ?? provs.first?.id

            self.draftPorts = portList.map {
                KumaPortMappingItem(id: $0.id, local: "\($0.localPort)", remote: "\($0.remotePort)")
            }

            if self.activeCategory == .kubernetes && self.kubeConfigVM == nil {
                self.kubeConfigVM = KubeConfigViewModel()
            }
        } catch {
            Self.logger.error("Failed to load service details for \(id): \(error.localizedDescription)")
        }
    }

    // MARK: - Instant Apply & Auto-Commit Engine

    /// Schedules an auto-commit with debouncing (300ms) for high-frequency text editing.
    public func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled, let self else { return }
                await self.commitChanges()
            } catch is CancellationError {
                // Expected structured concurrency cancellation on rapid keystrokes
                return
            } catch {
                Self.logger.error("Auto-save task error: \(error.localizedDescription)")
            }
        }
    }

    /// Immediately commits changes to SQLite and broadcasts synchronization event.
    public func commitChanges() async {
        guard var srv = service else { return }
        srv.updatedAt = Date()
        self.service = srv

        guard var activeProv = activeProvider else { return }
        activeProv.updatedAt = Date()

        let realPorts = draftPorts.compactMap { item -> ServicePortMapping? in
            guard let local = Int(item.local), let remote = Int(item.remote), local > 0, remote > 0 else { return nil }
            return ServicePortMapping(id: item.id, serviceID: self.serviceID, localPort: local, remotePort: remote, protocolType: "TCP")
        }

        do {
            // Handle secure field encryption if applicable
            if activeProv.type == .ssh {
                if let key = activeProv.sshKeyPath, !key.isEmpty && !key.starts(with: "vault:") {
                    activeProv.sshKeyPath = try await CryptoVault.shared.encrypt(plainText: key)
                }
                if let pass = activeProv.sshPassword, !pass.isEmpty && !pass.starts(with: "vault:") {
                    activeProv.sshPassword = try await CryptoVault.shared.encrypt(plainText: pass)
                }
            } else if activeProv.type == .tunnel {
                if let token = activeProv.ngrokAuthToken, !token.isEmpty && !token.starts(with: "vault:") {
                    activeProv.ngrokAuthToken = try await CryptoVault.shared.encrypt(plainText: token)
                }
            }

            try await serviceRepository.updateService(srv)
            try await serviceRepository.updateProvider(activeProv)
            try await serviceRepository.savePortMappings(realPorts, forService: serviceID)

            // Update in-memory providers list
            if let idx = providers.firstIndex(where: { $0.id == activeProv.id }) {
                providers[idx] = activeProv
            }

            // Broadcast passive notification to notify Deck and surrounding views
            NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
        } catch is CancellationError {
            // Structured task was cancelled, ignore
            return
        } catch {
            Self.logger.error("Failed to commit changes for service \(self.serviceID): \(error.localizedDescription)")
        }
    }

    // MARK: - Discrete Provider Operations

    public func switchProvider(to providerID: UUID) {
        guard var srv = service else { return }
        self.activeProviderID = providerID
        srv.activeProviderID = providerID
        srv.updatedAt = Date()
        self.service = srv

        if let prov = providers.first(where: { $0.id == providerID }), prov.type == .kubernetes && kubeConfigVM == nil {
            self.kubeConfigVM = KubeConfigViewModel()
        }

        Task {
            do {
                try await serviceRepository.updateService(srv)
                NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
            } catch {
                Self.logger.error("Failed to switch active provider for service \(srv.id): \(error.localizedDescription)")
            }
        }
    }

    public func addProvider(_ provider: Provider) {
        Task {
            do {
                try await serviceRepository.insertProvider(provider)
                self.providers.append(provider)
                self.switchProvider(to: provider.id)
                NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
            } catch {
                Self.logger.error("Failed to add provider: \(error.localizedDescription)")
            }
        }
    }

    public func updateProviderDirectly(_ provider: Provider) {
        Task {
            do {
                try await serviceRepository.updateProvider(provider)
                if let idx = self.providers.firstIndex(where: { $0.id == provider.id }) {
                    self.providers[idx] = provider
                }
                NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
            } catch {
                Self.logger.error("Failed to update provider \(provider.id): \(error.localizedDescription)")
            }
        }
    }

    public func deleteProvider(_ provider: Provider) {
        Task {
            do {
                try await serviceRepository.deleteProvider(id: provider.id)
                self.providers.removeAll(where: { $0.id == provider.id })
                if self.activeProviderID == provider.id {
                    self.activeProviderID = self.providers.first?.id
                    if var srv = self.service {
                        srv.activeProviderID = self.activeProviderID
                        try await self.serviceRepository.updateService(srv)
                        self.service = srv
                    }
                }
                NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
            } catch {
                Self.logger.error("Failed to delete provider \(provider.id): \(error.localizedDescription)")
            }
        }
    }

    public func toggleDisabled(_ isDisabled: Bool) {
        guard var srv = service else { return }
        srv.isDisabled = isDisabled
        srv.updatedAt = Date()
        self.service = srv

        Task {
            do {
                try await serviceRepository.updateService(srv)
                NotificationCenter.default.post(name: .kumaServiceUpdated, object: serviceID)
            } catch {
                Self.logger.error("Failed to toggle disabled state for \(self.serviceID): \(error.localizedDescription)")
            }
        }
    }

    public func deleteService() {
        Task {
            do {
                try await serviceRepository.deleteService(id: serviceID)
                NotificationCenter.default.post(name: .kumaServiceDeleted, object: serviceID)
            } catch {
                Self.logger.error("Failed to delete service \(self.serviceID): \(error.localizedDescription)")
            }
        }
    }
}
