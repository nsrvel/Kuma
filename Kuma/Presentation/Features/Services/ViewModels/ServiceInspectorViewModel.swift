import Foundation
import Observation
import SwiftUI
import os

@Observable
@MainActor
public final class ServiceInspectorViewModel {
    static let logger = Logger(subsystem: "lokastudio.kuma", category: "ServiceInspectorViewModel")

    public var serviceID: UUID
    public let workspaceID: UUID
    let serviceRepository: any ServiceRepositoryProtocol

    public var service: Service? = nil
    public var providers: [Provider] = []
    public var activeProviderID: UUID? = nil
    public var draftPorts: [KumaPortMappingItem] = []

    public var isViewingLogs: Bool = false
    public var showDeleteConfirmation: Bool = false
    public var stateStore: ServiceStateStore?
    public var kubeConfigVM: KubeConfigViewModel? = nil

    var autoSaveTask: Task<Void, Never>? = nil

    public var executionState: ServiceExecutionState {
        stateStore?.state(for: serviceID) ?? (isRunning ? .running(pid: 0) : .idle)
    }

    public var isRunning: Bool {
        get {
            if let store = stateStore {
                return store.state(for: serviceID).isOperational
            }
            return _legacyIsRunning
        }
        set {
            _legacyIsRunning = newValue
        }
    }
    private var _legacyIsRunning: Bool = false

    public var activeProvider: Provider? {
        if let activeProviderID {
            return providers.first(where: { $0.id == activeProviderID })
        }
        return providers.first
    }

    public var activeCategory: ProviderCategory {
        activeProvider?.type ?? .docker
    }

    public func toggleRunning() {
        Task {
            let wasRunning = isRunning
            if wasRunning {
                stateStore?.setExecutionState(.stopping, for: serviceID)
                ServiceStateNotification.post(serviceID: serviceID, state: .stopping)
                await ServiceExecutionEngine.shared.stop(serviceID: serviceID)
                stateStore?.setExecutionState(.idle, for: serviceID)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    self.isRunning = false
                }
                ServiceStateNotification.post(serviceID: serviceID, state: .stopped)
            } else {
                stateStore?.setExecutionState(.starting, for: serviceID)
                ServiceStateNotification.post(serviceID: serviceID, state: .starting)
                do {
                    try await ServiceExecutionEngine.shared.start(serviceID: serviceID)
                    if let proc = await ProcessRegistry.shared.getSnapshot(serviceID: serviceID) {
                        stateStore?.setExecutionState(.running(pid: proc.pid), for: serviceID)
                    } else {
                        stateStore?.setExecutionState(.running(pid: 0), for: serviceID)
                    }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        self.isRunning = true
                    }
                    let pid = await ProcessRegistry.shared.getSnapshot(serviceID: serviceID)?.pid ?? 0
                    ServiceStateNotification.post(serviceID: serviceID, state: .running, pid: pid)
                } catch {
                    Self.logger.error("Failed to start service \(self.serviceID): \(error.localizedDescription)")
                    stateStore?.setExecutionState(.crashed(exitCode: 1), for: serviceID)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        self.isRunning = false
                    }
                    ServiceStateNotification.post(serviceID: serviceID, state: .crashed, exitCode: 1)
                }
            }
            postUpdatedNotification()
        }
    }

    func postUpdatedNotification() {
        NotificationCenter.default.post(
            name: .kumaServiceUpdated,
            object: serviceID,
            userInfo: ["source": "inspector"]
        )
    }

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository(),
        stateStore: ServiceStateStore? = nil
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        self.serviceRepository = serviceRepository
        self.stateStore = stateStore
    }
}
