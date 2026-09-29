import Foundation
import os

/// Runner responsible for Kubernetes port-forwarding processes using `kubectl`.
/// Ephemeral `kubectl get` / list helpers use `EphemeralCLI`; port-forward is a **managed** process via `ProcessLaunching`.
public final class KubernetesRunner: ServiceRunnerProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "KubernetesRunner")

    private let processLauncher: any ProcessLaunching
    private let serviceRepository: any ServiceRepositoryProtocol

    public nonisolated init(
        processLauncher: any ProcessLaunching = ProcessRegistryLauncher(),
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.processLauncher = processLauncher
        self.serviceRepository = serviceRepository
    }

    public func start(
        service: Service,
        provider: Provider
    ) async throws {
        guard let kubectl = await KumaSettingsExecutableResolver.kubectl() else {
            throw ServiceExecutionError.binaryNotFound("kubectl")
        }

        let portMappings = try await serviceRepository.fetchPortMappings(forService: service.id)
        if portMappings.isEmpty {
            throw ServiceExecutionError.invalidConfiguration("At least one port mapping (Local:Remote) is required for Kubernetes port-forwarding.")
        }

        let execConfig = try await KubeConfigExecutionResolver.resolve(for: provider)
        let namespace = provider.kubeNamespace?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = execConfig.context?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolved = try await KubeTargetResolver.resolve(
            provider: provider,
            kubectlPath: kubectl,
            exec: execConfig
        )

        var args = ["port-forward", resolved.kubectlReference]

        if let kubeconfigPath = execConfig.kubeconfigPath, !kubeconfigPath.isEmpty {
            args.append("--kubeconfig")
            args.append(kubeconfigPath)
        }

        for mapping in portMappings {
            args.append("\(mapping.localPort):\(mapping.remotePort)")
        }

        if let namespace, !namespace.isEmpty {
            args.append("-n")
            args.append(namespace)
        }

        if let context, !context.isEmpty {
            args.append("--context")
            args.append(context)
        }

        for mapping in portMappings {
            try await LocalPortConflictResolver.shared.ensurePortAvailable(
                port: mapping.localPort,
                startingServiceID: service.id,
                startingServiceName: service.name
            )
        }

        _ = try await processLauncher.launch(
            serviceID: service.id,
            serviceName: service.name,
            executable: kubectl,
            arguments: args,
            workingDirectory: nil,
            environment: nil,
            onOutput: nil
        )
    }

    public func stop(serviceID: UUID) async {
        await processLauncher.stop(serviceID: serviceID)
    }

    public func isRunning(serviceID: UUID) async -> Bool {
        await processLauncher.isRunning(serviceID: serviceID)
    }
}
