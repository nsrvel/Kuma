import Foundation
import os

/// Typed errors for service execution
public enum ServiceExecutionError: LocalizedError, Sendable {
    case serviceNotFound(UUID)
    case noActiveProvider(UUID)
    case invalidConfiguration(String)
    case binaryNotFound(String)
    case processFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serviceNotFound(let id):
            return "Service '\(id)' was not found."
        case .noActiveProvider:
            return "No active runner provider is configured for this service."
        case .invalidConfiguration(let msg):
            return "Invalid configuration: \(msg)"
        case .binaryNotFound(let name):
            return "Required binary '\(name)' could not be located on this Mac."
        case .processFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}

/// Central orchestrator coordinating modular runners and log pipelines for services.
public final class ServiceExecutionEngine: Sendable {
    public static let shared = ServiceExecutionEngine()
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ServiceExecutionEngine")

    private let serviceRepository: any ServiceRepositoryProtocol
    private let activePipelinesLock = NSLock()
    nonisolated(unsafe) private var activePipelines: [UUID: ServiceLogPipeline] = [:]

    private let kubernetesRunner: KubernetesRunner
    private let shellRunner: ShellRunner
    private let containerRunner: ContainerRunner
    private let sshRunner: SSHTunnelRunner
    private let healthCheckRunner: HealthCheckRunner
    private let tunnelRunner: TunnelRunner
    private let processMonitorRunner: ProcessMonitorRunner

    public init(
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository(),
        processRegistry: ProcessRegistry = .shared
    ) {
        self.serviceRepository = serviceRepository
        self.kubernetesRunner = KubernetesRunner(processRegistry: processRegistry, serviceRepository: serviceRepository)
        self.shellRunner = ShellRunner(processRegistry: processRegistry)
        self.containerRunner = ContainerRunner(processRegistry: processRegistry)
        self.sshRunner = SSHTunnelRunner(processRegistry: processRegistry, serviceRepository: serviceRepository)
        self.healthCheckRunner = HealthCheckRunner()
        self.tunnelRunner = TunnelRunner(processRegistry: processRegistry)
        self.processMonitorRunner = ProcessMonitorRunner()
    }

    /// Starts a service using its configured active provider.
    public func start(serviceID: UUID) async throws {
        // Idempotency check: Skip if already actively running
        if await isServiceRunning(serviceID: serviceID) {
            Self.logger.info("Service '\(serviceID)' is already actively running. Skipping rerun.")
            return
        }

        guard let service = try await serviceRepository.fetchService(id: serviceID) else {
            throw ServiceExecutionError.serviceNotFound(serviceID)
        }

        let providers = try await serviceRepository.fetchProviders(forService: serviceID)
        guard let provider = providers.first(where: { $0.id == service.activeProviderID }) ?? providers.first else {
            throw ServiceExecutionError.noActiveProvider(serviceID)
        }

        Self.logger.info("Starting service '\(service.name)' with provider '\(provider.type.rawValue)'")

        let pipeline = ServiceLogPipeline(serviceID: service.id, serviceName: service.name)
        setPipeline(pipeline, for: serviceID)

        let runner = runner(for: provider.type)
        do {
            try await runner.start(service: service, provider: provider, pipeline: pipeline)
        } catch {
            await pipeline.emit(level: "ERROR", message: "Failed to start: \(error.localizedDescription)")
            await pipeline.finish()
            _ = removePipeline(for: serviceID)
            throw error
        }
    }

    /// Stops a running service across all possible runner implementations.
    public func stop(serviceID: UUID) async {
        Self.logger.info("Stopping service \(serviceID)...")

        await kubernetesRunner.stop(serviceID: serviceID)
        await shellRunner.stop(serviceID: serviceID)
        await containerRunner.stop(serviceID: serviceID)
        await sshRunner.stop(serviceID: serviceID)
        await healthCheckRunner.stop(serviceID: serviceID)
        await tunnelRunner.stop(serviceID: serviceID)
        await processMonitorRunner.stop(serviceID: serviceID)

        let pipeline = removePipeline(for: serviceID)
        await pipeline?.finish()
    }

    /// Checks if a service is actively running under any runner.
    public func isServiceRunning(serviceID: UUID) async -> Bool {
        if await kubernetesRunner.isRunning(serviceID: serviceID) { return true }
        if await shellRunner.isRunning(serviceID: serviceID) { return true }
        if await containerRunner.isRunning(serviceID: serviceID) { return true }
        if await sshRunner.isRunning(serviceID: serviceID) { return true }
        if await healthCheckRunner.isRunning(serviceID: serviceID) { return true }
        if await tunnelRunner.isRunning(serviceID: serviceID) { return true }
        if await processMonitorRunner.isRunning(serviceID: serviceID) { return true }
        return false
    }

    private func setPipeline(_ pipeline: ServiceLogPipeline, for serviceID: UUID) {
        activePipelinesLock.lock()
        defer { activePipelinesLock.unlock() }
        activePipelines[serviceID] = pipeline
    }

    private func removePipeline(for serviceID: UUID) -> ServiceLogPipeline? {
        activePipelinesLock.lock()
        defer { activePipelinesLock.unlock() }
        return activePipelines.removeValue(forKey: serviceID)
    }

    private func runner(for category: ProviderCategory) -> any ServiceRunnerProtocol {
        switch category {
        case .kubernetes:      return kubernetesRunner
        case .shell:           return shellRunner
        case .docker, .podman: return containerRunner
        case .ssh:             return sshRunner
        case .httpCheck:       return healthCheckRunner
        case .tunnel:          return tunnelRunner
        case .processMonitor:  return processMonitorRunner
        }
    }
}
