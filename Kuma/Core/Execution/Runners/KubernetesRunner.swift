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

        let targetType = provider.kubeTargetType ?? "pod"
        let namespace = provider.kubeNamespace?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = provider.kubeContext?.trimmingCharacters(in: .whitespacesAndNewlines)
        let usePattern = provider.usePattern ?? true

        var resolvedTarget = "\(targetType)/\(targetName)"

        // Dynamic pod pattern resolution
        if usePattern && (targetType == "pod" || targetType.isEmpty) {
            let matchedPod = try await resolveDynamicPod(
                kubectlPath: kubectl,
                targetPattern: targetName,
                namespace: namespace,
                context: context,
                customKubeConfigPath: provider.customKubeConfigPath,
                serviceID: service.id,
                serviceName: service.name,
                pipeline: pipeline
            )
            resolvedTarget = "pod/\(matchedPod)"
        }

        var args = ["port-forward", resolvedTarget]

        if let customConfig = provider.customKubeConfigPath?.trimmingCharacters(in: .whitespacesAndNewlines), !customConfig.isEmpty {
            args.append("--kubeconfig")
            args.append(customConfig)
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

        // Release local ports from orphaned processes
        for mapping in portMappings {
            await killProcessOccupying(port: mapping.localPort, pipeline: pipeline)
        }

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

    // MARK: - Dynamic Pod Discovery

    private func resolveDynamicPod(
        kubectlPath: String,
        targetPattern: String,
        namespace: String?,
        context: String?,
        customKubeConfigPath: String?,
        serviceID: UUID,
        serviceName: String,
        pipeline: ServiceLogPipeline
    ) async throws -> String {
        await pipeline.emit(level: "INFO", message: "Discovering active pods matching pattern '\(targetPattern)'...")

        var listArgs = ["get", "pods", "-o", "jsonpath={range .items[?(@.status.phase==\"Running\")]}{.metadata.name}{\"\\n\"}{end}"]

        if let customConfig = customKubeConfigPath?.trimmingCharacters(in: .whitespacesAndNewlines), !customConfig.isEmpty {
            listArgs.append("--kubeconfig")
            listArgs.append(customConfig)
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
            throw ServiceExecutionError.processFailed("Failed to execute pod discovery query: \(error.localizedDescription)")
        }

        // Read pipe concurrently to prevent buffer deadlocks if output exceeds 64KB
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
        let podNames = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        if podNames.isEmpty {
            let errBytes = await stderrData
            try? stderrPipe.fileHandleForReading.close()
            let errMsg = String(data: errBytes, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let errMsg, !errMsg.isEmpty {
                throw ServiceExecutionError.processFailed("Kubectl pod discovery error: \(errMsg)")
            } else {
                throw ServiceExecutionError.processFailed("No running pods found in namespace '\(namespace ?? "default")'.")
            }
        } else {
            _ = await stderrData
            try? stderrPipe.fileHandleForReading.close()
        }

        let cleanedPattern = targetPattern.replacingOccurrences(of: "*", with: "")
        let matched = podNames.first { name in
            if targetPattern.contains("*") {
                return name.localizedCaseInsensitiveContains(cleanedPattern)
            } else {
                return name == targetPattern || name.hasPrefix(targetPattern) || name.localizedCaseInsensitiveContains(targetPattern)
            }
        }

        guard let targetPod = matched else {
            throw ServiceExecutionError.processFailed("Found \(podNames.count) running pods, but none matched pattern '\(targetPattern)'. Available: \(podNames.prefix(3).joined(separator: ", "))")
        }

        await pipeline.emit(level: "INFO", message: "Matched active pod: '\(targetPod)'. Starting port-forward...")
        return targetPod
    }

    private func killProcessOccupying(port: Int, pipeline: ServiceLogPipeline) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-ti", ":\(port)"]
        let pipe = Pipe()
        defer { try? pipe.fileHandleForReading.close() }
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                let pids = output.components(separatedBy: .newlines).compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                let currentPID = ProcessInfo.processInfo.processIdentifier

                for pid in pids where pid != currentPID {
                    await pipeline.emit(level: "WARN", message: "Port \(port) was held by zombie process (PID \(pid)). Releasing port...")
                    kill(pid, SIGTERM)
                }

                if !pids.isEmpty {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        } catch {
            Self.logger.debug("lsof check for port \(port) exited: \(error.localizedDescription)")
        }
    }
}
