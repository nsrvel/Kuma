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
        provider: Provider,
        pipeline: ServiceLogPipeline
    ) async throws {
        guard let kubectl = await KumaSettingsExecutableResolver.kubectl() else {
            throw ServiceExecutionError.binaryNotFound("kubectl")
        }

        let portMappings = try await serviceRepository.fetchPortMappings(forService: service.id)
        if portMappings.isEmpty {
            throw ServiceExecutionError.invalidConfiguration("At least one port mapping (Local:Remote) is required for Kubernetes port-forwarding.")
        }

        guard let targetName = provider.targetName?.trimmingCharacters(in: .whitespacesAndNewlines), !targetName.isEmpty else {
            throw ServiceExecutionError.invalidConfiguration("Target resource name is required (e.g. my-app-service or pod pattern).")
        }

        let kubeTarget = KubeTargetType(rawValue: provider.kubeTargetType ?? "") ?? .pod
        let namespace = provider.kubeNamespace?.trimmingCharacters(in: .whitespacesAndNewlines)
        let usePattern = provider.usePattern ?? true
        let execConfig = try await KubeConfigExecutionResolver.resolve(for: provider)
        let kubeconfigPath = execConfig.kubeconfigPath
        let context = execConfig.context?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedName: String
        if usePattern {
            resolvedName = try await resolveDynamicResourceName(
                kubectlPath: kubectl,
                targetType: kubeTarget,
                targetPattern: targetName,
                namespace: namespace,
                context: context,
                kubeconfigPath: kubeconfigPath,
                pipeline: pipeline
            )
        } else {
            resolvedName = targetName
        }

        let resolvedTarget = "\(kubeTarget.portForwardKind)/\(resolvedName)"

        try await preflightTargetExists(
            kubectlPath: kubectl,
            target: resolvedTarget,
            namespace: namespace,
            context: context,
            kubeconfigPath: kubeconfigPath,
            pipeline: pipeline
        )

        var args = ["port-forward", resolvedTarget]

        if let kubeconfigPath, !kubeconfigPath.isEmpty {
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
                startingServiceName: service.name,
                pipeline: pipeline
            )
        }

        await pipeline.emit(level: "INFO", message: "Starting port-forward to \(resolvedTarget)...")

        _ = try await processLauncher.launch(
            serviceID: service.id,
            serviceName: service.name,
            executable: kubectl,
            arguments: args,
            workingDirectory: nil,
            environment: nil,
            onOutput: pipeline.makeOutputHandler()
        )
    }

    public func stop(serviceID: UUID) async {
        await processLauncher.stop(serviceID: serviceID)
    }

    public func isRunning(serviceID: UUID) async -> Bool {
        await processLauncher.isRunning(serviceID: serviceID)
    }

    // MARK: - Dynamic resource discovery (pod / service / deployment)

    private func resolveDynamicResourceName(
        kubectlPath: String,
        targetType: KubeTargetType,
        targetPattern: String,
        namespace: String?,
        context: String?,
        kubeconfigPath: String?,
        pipeline: ServiceLogPipeline
    ) async throws -> String {
        await pipeline.emit(
            level: "INFO",
            message: "Discovering \(targetType.displayLabel) resources matching pattern '\(targetPattern)'..."
        )

        var listArgs = [
            "get", targetType.listResource,
            "-o", "jsonpath=\(targetType.listNameJSONPath)",
        ]

        if let kubeconfigPath, !kubeconfigPath.isEmpty {
            listArgs.append("--kubeconfig")
            listArgs.append(kubeconfigPath)
        }

        if let namespace, !namespace.isEmpty {
            listArgs.append("-n")
            listArgs.append(namespace)
        }

        if let context, !context.isEmpty {
            listArgs.append("--context")
            listArgs.append(context)
        }

        let result = try await EphemeralCLI.run(
            executablePath: kubectlPath,
            arguments: listArgs,
            timeout: KumaExecutionTimeouts.kubectlSubcommand,
            stdio: .captureSeparated
        )

        let output = result.stdout
        let resourceNames = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if resourceNames.isEmpty {
            let errMsg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !errMsg.isEmpty {
                throw ServiceExecutionError.processFailed("Kubectl \(targetType.listResource) discovery error: \(errMsg)")
            }
            let emptyHint = targetType == .pod ? "No running pods found" : "No \(targetType.listResource) found"
            throw ServiceExecutionError.processFailed("\(emptyHint) in namespace '\(namespace ?? "default")'.")
        }

        guard let matched = KubeTargetNameMatcher.firstMatch(pattern: targetPattern, in: resourceNames) else {
            throw ServiceExecutionError.processFailed(
                "Found \(resourceNames.count) \(targetType.listResource), but none matched pattern '\(targetPattern)'. Available: \(resourceNames.prefix(3).joined(separator: ", "))"
            )
        }

        await pipeline.emit(level: "INFO", message: "Matched \(targetType.displayLabel): '\(matched)'.")
        return matched
    }

    private func preflightTargetExists(
        kubectlPath: String,
        target: String,
        namespace: String?,
        context: String?,
        kubeconfigPath: String?,
        pipeline: ServiceLogPipeline
    ) async throws {
        var getArgs = ["get", target, "-o", "name"]
        if let kubeconfigPath, !kubeconfigPath.isEmpty {
            getArgs.append(contentsOf: ["--kubeconfig", kubeconfigPath])
        }
        if let namespace, !namespace.isEmpty {
            getArgs.append(contentsOf: ["-n", namespace])
        }
        if let context, !context.isEmpty {
            getArgs.append(contentsOf: ["--context", context])
        }

        let result = try await EphemeralCLI.run(
            executablePath: kubectlPath,
            arguments: getArgs,
            timeout: KumaExecutionTimeouts.kubectlSubcommand,
            stdio: .captureSeparated
        )

        if result.terminationStatus == 0 {
            await pipeline.emit(level: "INFO", message: "Preflight OK: \(target) exists in cluster.")
            return
        }

        let errMsg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = errMsg.isEmpty ? "exit code \(result.terminationStatus)" : errMsg
        throw ServiceExecutionError.processFailed("Preflight failed for \(target): \(detail)")
    }

}
