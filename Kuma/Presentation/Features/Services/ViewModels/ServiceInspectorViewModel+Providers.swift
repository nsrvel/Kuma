import os
import SwiftUI

extension ServiceInspectorViewModel {
    public func switchProvider(to providerID: UUID) {
        guard providerID != activeProviderID else { return }

        Task {
            let wasRunning = isRunning
            await flushPendingAutoSave()

            guard var srv = service else { return }

            if wasRunning {
                stateStore?.setExecutionState(.stopping, for: serviceID)
                await ServiceExecutionEngine.shared.stop(serviceID: serviceID)
            }

            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                self.activeProviderID = providerID
                srv.activeProviderID = providerID
                srv.updatedAt = Date()
                self.service = srv
            }

            do {
                try await serviceRepository.updateService(srv)
                await reloadDraftPortsForActiveProvider()
                await syncKubeConfigSelectionFromActiveProvider()
                postUpdatedNotification()

                if wasRunning {
                    stateStore?.setExecutionState(.starting, for: serviceID)
                    try await ServiceExecutionEngine.shared.start(serviceID: serviceID)
                    if let proc = await ProcessRegistry.shared.getSnapshot(serviceID: serviceID) {
                        stateStore?.setExecutionState(.running(pid: proc.pid), for: serviceID)
                    } else {
                        stateStore?.setExecutionState(.running(pid: 0), for: serviceID)
                    }
                    self.isRunning = true
                    let pid = await ProcessRegistry.shared.getSnapshot(serviceID: serviceID)?.pid ?? 0
                    ServiceStateNotification.post(serviceID: serviceID, state: .running, pid: pid)
                }
            } catch {
                Self.logger.error("Failed to switch active provider for service \(srv.id): \(error.localizedDescription)")
            }
        }
    }

    public func addProvider(_ provider: Provider) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            self.providers.append(provider)
            self.activeProviderID = provider.id
            if var srv = self.service {
                srv.activeProviderID = provider.id
                srv.updatedAt = Date()
                self.service = srv
            }
        }

        if provider.type == .kubernetes && kubeConfigVM == nil {
            self.kubeConfigVM = KubeConfigViewModel()
        }

        if provider.type == .kubernetes || provider.type == .ssh {
            draftPorts = [KumaPortMappingItem()]
        } else {
            draftPorts = []
        }

        Task {
            do {
                try await serviceRepository.insertProvider(provider)
                if let srv = self.service {
                    try await serviceRepository.updateService(srv)
                }
                postUpdatedNotification()
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
                postUpdatedNotification()
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
                postUpdatedNotification()
            } catch {
                Self.logger.error("Failed to delete provider \(provider.id): \(error.localizedDescription)")
            }
        }
    }

    public func toggleStarred() {
        guard var srv = service else { return }
        srv.isStarred.toggle()
        srv.updatedAt = Date()
        self.service = srv

        Task {
            do {
                _ = try await serviceRepository.toggleStarred(serviceID: serviceID)
                postUpdatedNotification()
            } catch {
                Self.logger.error("Failed to toggle starred for \(self.serviceID): \(error.localizedDescription)")
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
                postUpdatedNotification()
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
