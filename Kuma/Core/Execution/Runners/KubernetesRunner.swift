import Foundation
import os

/// Runner responsible for Kubernetes port-forwarding processes using `kubectl`.
public final class KubernetesRunner: ServiceRunnerProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "KubernetesRunner")

    private let processRegistry: ProcessRegistry
    private let serviceRepository: any ServiceRepositoryProtocol

    public nonisolated init(
        processRegistry: ProcessRegistry = .shared,
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.processRegistry = processRegistry
        self.serviceRepository = serviceRepository
    }

    public func start(
        service: Service,
        provider: Provider,
        pipeline: ServiceLogPipeline
    ) async throws {
        guard let kubectl = await EnvironmentPathResolver.shared.resolveExecutablePath(for: "kubectl") else {
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

        _ = try await processRegistry.launch(
            serviceID: service.id,
            serviceName: service.name,
            executable: kubectl,
            arguments: args,
            onOutput: pipeline.makeOutputHandler()
        )
    }

    public func stop(serviceID: UUID) async {
        await processRegistry.stop(serviceID: serviceID)
    }

    public func isRunning(serviceID: UUID) async -> Bool {
        await processRegistry.isRunning(serviceID: serviceID)
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: kubectlPath)
        process.arguments = listArgs
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ServiceExecutionError.processFailed("Failed to list \(targetType.listResource): \(error.localizedDescription)")
        }

        async let stdoutData = Task.detached {
            stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        }.value
        async let stderrData = Task.detached {
            stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }.value

        await withTaskCancellationHandler {
            process.waitUntilExit()
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }

        let data = await stdoutData
        try? stdoutPipe.fileHandleForReading.close()
        let output = String(data: data, encoding: .utf8) ?? ""
        let resourceNames = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if resourceNames.isEmpty {
            let errBytes = await stderrData
            try? stderrPipe.fileHandleForReading.close()
            let errMsg = String(data: errBytes, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let errMsg, !errMsg.isEmpty {
                throw ServiceExecutionError.processFailed("Kubectl \(targetType.listResource) discovery error: \(errMsg)")
            }
            let emptyHint = targetType == .pod ? "No running pods found" : "No \(targetType.listResource) found"
            throw ServiceExecutionError.processFailed("\(emptyHint) in namespace '\(namespace ?? "default")'.")
        } else {
            _ = await stderrData
            try? stderrPipe.fileHandleForReading.close()
        }

        guard let matched = KubeTargetNameMatcher.firstMatch(pattern: targetPattern, in: resourceNames) else {
            throw ServiceExecutionError.processFailed(
                "Found \(resourceNames.count) \(targetType.listResource), but none matched pattern '\(targetPattern)'. Available: \(resourceNames.prefix(3).joined(separator: ", "))"
            )
        }

        await pipeline.emit(level: "INFO", message: "Matched \(targetType.displayLabel): '\(matched)'.")
        return matched
    }

}
