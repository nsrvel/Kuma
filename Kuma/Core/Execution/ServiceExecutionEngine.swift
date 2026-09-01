import Foundation
import os

/// Central orchestrator for running services and dispatching to appropriate providers
@MainActor
public final class ServiceExecutionEngine {
    public static let shared = ServiceExecutionEngine()
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ServiceExecutionEngine")

    private let processRegistry: ProcessRegistry
    private let serviceRepository: any ServiceRepositoryProtocol

    public init(
        processRegistry: ProcessRegistry = .shared,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.processRegistry = processRegistry
        self.serviceRepository = serviceRepository
    }

    /// Starts a service using its configured active provider.
    public func start(serviceID: UUID) async throws {
        guard let service = try await serviceRepository.fetchService(id: serviceID) else {
            throw NSError(domain: "ServiceExecutionEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "Service not found"])
        }

        let providers = try await serviceRepository.fetchProviders(forService: serviceID)
        guard let provider = providers.first(where: { $0.id == service.activeProviderID }) ?? providers.first else {
            throw NSError(domain: "ServiceExecutionEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "No active provider configured"])
        }

        Self.logger.info("Executing service '\(service.name)' with provider '\(provider.type.rawValue)'")

        switch provider.type {
        case .shell:
            guard let runCommand = provider.runCommand, !runCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "ServiceExecutionEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "No shell command specified"])
            }
            _ = try await processRegistry.launch(
                serviceID: serviceID,
                executable: "/bin/zsh",
                arguments: ["-c", runCommand],
                workingDirectory: provider.workingDirectory,
                onOutput: { text in
                    LogAggregator.appendLog(serviceID: serviceID, serviceName: service.name, level: "INFO", message: text)
                }
            )

        case .docker, .podman:
            let cmd = provider.type == .docker ? "docker" : "podman"
            let binaryPath = await EnvironmentPathResolver.shared.resolveExecutablePath(for: cmd) ?? "/usr/local/bin/\(cmd)"
            let args = ["compose", "up"]
            _ = try await processRegistry.launch(
                serviceID: serviceID,
                executable: binaryPath,
                arguments: args,
                onOutput: { text in
                    LogAggregator.appendLog(serviceID: serviceID, serviceName: service.name, level: "INFO", message: text)
                }
            )

        case .kubernetes:
            let kubectl = await EnvironmentPathResolver.shared.resolveExecutablePath(for: "kubectl") ?? "/usr/local/bin/kubectl"
            let portMappings = try await serviceRepository.fetchPortMappings(forService: serviceID)
            var args = ["port-forward"]

            if let targetType = provider.kubeTargetType, let targetName = provider.targetName {
                args.append("\(targetType)/\(targetName)")
            } else if let targetName = provider.targetName {
                args.append("pod/\(targetName)")
            }

            for mapping in portMappings {
                args.append("\(mapping.localPort):\(mapping.remotePort)")
            }

            if let namespace = provider.kubeNamespace, !namespace.isEmpty {
                args.append("-n")
                args.append(namespace)
            }

            _ = try await processRegistry.launch(
                serviceID: serviceID,
                executable: kubectl,
                arguments: args,
                onOutput: { text in
                    LogAggregator.appendLog(serviceID: serviceID, serviceName: service.name, level: "INFO", message: text)
                }
            )

        case .ssh:
            guard let host = provider.sshHost, !host.isEmpty else {
                throw NSError(domain: "ServiceExecutionEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "SSH Host not configured"])
            }
            let user = provider.sshUser ?? NSUserName()
            let port = provider.sshPort ?? 22
            let portMappings = try await serviceRepository.fetchPortMappings(forService: serviceID)

            var args = ["-N", "-p", "\(port)"]
            for mapping in portMappings {
                args.append("-L")
                args.append("\(mapping.localPort):localhost:\(mapping.remotePort)")
            }
            args.append("\(user)@\(host)")

            _ = try await processRegistry.launch(
                serviceID: serviceID,
                executable: "/usr/bin/ssh",
                arguments: args,
                onOutput: { text in
                    LogAggregator.appendLog(serviceID: serviceID, serviceName: service.name, level: "INFO", message: text)
                }
            )

        case .httpCheck, .tunnel, .processMonitor:
            Self.logger.info("Service provider type '\(provider.type.rawValue)' activated")
        }
    }

    /// Stops a running service.
    public func stop(serviceID: UUID) async {
        await processRegistry.stop(serviceID: serviceID)
    }

    /// Checks operational state of a service.
    public func isServiceRunning(serviceID: UUID) async -> Bool {
        await processRegistry.isRunning(serviceID: serviceID)
    }
}
