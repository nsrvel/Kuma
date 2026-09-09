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

/// Central orchestrator for running services and dispatching to appropriate providers.
/// Not isolated to MainActor to prevent UI thread blocking during disk I/O and process launches.
public final class ServiceExecutionEngine: Sendable {
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
            throw ServiceExecutionError.serviceNotFound(serviceID)
        }

        let providers = try await serviceRepository.fetchProviders(forService: serviceID)
        guard let provider = providers.first(where: { $0.id == service.activeProviderID }) ?? providers.first else {
            throw ServiceExecutionError.noActiveProvider(serviceID)
        }

        Self.logger.info("Starting service '\(service.name)' with provider '\(provider.type.rawValue)'")

        switch provider.type {
        case .kubernetes:
            try await startKubernetes(service: service, provider: provider)

        case .shell:
            try await startShell(service: service, provider: provider)

        case .docker, .podman:
            try await startContainer(service: service, provider: provider)

        case .ssh:
            try await startSSH(service: service, provider: provider)

        case .httpCheck, .tunnel, .processMonitor:
            Self.logger.info("Service provider type '\(provider.type.rawValue)' activated (passive mode)")
        }
    }

    // MARK: - Unified Logging Pipeline

    private func makeLogPipeline(serviceID: UUID, serviceName: String) -> @Sendable (String) -> Void {
        return { @Sendable text in
            // 1. Hot path: UI in-memory ring buffer (MainActor)
            LogAggregator.appendLog(serviceID: serviceID, serviceName: serviceName, level: "INFO", message: text)
            // 2. Cold path: Disk log writer (Background Actor)
            Task {
                await LogFileWriter.shared.append(serviceID: serviceID, level: "INFO", message: text)
            }
        }
    }

    // MARK: - Kubernetes Port Forwarding Runner

    private func startKubernetes(service: Service, provider: Provider) async throws {
        guard let kubectl = await EnvironmentPathResolver.shared.resolveExecutablePath(for: "kubectl") else {
            throw ServiceExecutionError.binaryNotFound("kubectl")
        }

        let portMappings = try await serviceRepository.fetchPortMappings(forService: service.id)
        if portMappings.isEmpty {
            throw ServiceExecutionError.invalidConfiguration("At least one port mapping (Local:Remote) is required for Kubernetes port-forwarding.")
        }

        guard let targetName = provider.targetName?.trimmingCharacters(in: .whitespacesAndNewlines), !targetName.isEmpty else {
            throw ServiceExecutionError.invalidConfiguration("Target resource name is required (e.g. forwarder-elasticsearch or my-service).")
        }

        let targetType = provider.kubeTargetType ?? "pod"
        let namespace = provider.kubeNamespace?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = provider.kubeContext?.trimmingCharacters(in: .whitespacesAndNewlines)
        let usePattern = provider.usePattern ?? true

        var resolvedTarget = "\(targetType)/\(targetName)"

        // If usePattern is enabled and targeting a pod, resolve real active pod name dynamically
        if usePattern && (targetType == "pod" || targetType.isEmpty) {
            let matchedPod = try await resolveDynamicPod(
                kubectlPath: kubectl,
                targetPattern: targetName,
                namespace: namespace,
                context: context,
                customKubeConfigPath: provider.customKubeConfigPath,
                serviceID: service.id,
                serviceName: service.name
            )
            resolvedTarget = "pod/\(matchedPod)"
        }

        var args = ["port-forward", resolvedTarget]

        // Custom kubeconfig flag
        if let customConfig = provider.customKubeConfigPath?.trimmingCharacters(in: .whitespacesAndNewlines), !customConfig.isEmpty {
            args.append("--kubeconfig")
            args.append(customConfig)
        }

        // Port mappings: local:remote
        for mapping in portMappings {
            args.append("\(mapping.localPort):\(mapping.remotePort)")
        }

        // Namespace flag
        if let namespace, !namespace.isEmpty {
            args.append("-n")
            args.append(namespace)
        }

        // Context flag
        if let context, !context.isEmpty {
            args.append("--context")
            args.append(context)
        }

        // Ensure local ports are cleared from orphaned/zombie background processes
        for mapping in portMappings {
            await killProcessOccupying(port: mapping.localPort, serviceID: service.id, serviceName: service.name)
        }

        let serviceID = service.id
        let serviceName = service.name

        _ = try await processRegistry.launch(
            serviceID: serviceID,
            serviceName: serviceName,
            executable: kubectl,
            arguments: args,
            onOutput: makeLogPipeline(serviceID: serviceID, serviceName: serviceName)
        )
    }

    // MARK: - Shell Runner

    private func startShell(service: Service, provider: Provider) async throws {
        guard let runCommand = provider.runCommand, !runCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceExecutionError.invalidConfiguration("No shell command specified.")
        }

        let serviceID = service.id
        let serviceName = service.name

        _ = try await processRegistry.launch(
            serviceID: serviceID,
            serviceName: serviceName,
            executable: "/bin/zsh",
            arguments: ["-c", runCommand],
            workingDirectory: provider.workingDirectory,
            onOutput: makeLogPipeline(serviceID: serviceID, serviceName: serviceName)
        )
    }

    // MARK: - Container Runner

    private func startContainer(service: Service, provider: Provider) async throws {
        let cmd = provider.type == .docker ? "docker" : "podman"
        guard let binaryPath = await EnvironmentPathResolver.shared.resolveExecutablePath(for: cmd) else {
            throw ServiceExecutionError.binaryNotFound(cmd)
        }

        var composeArgs = ["compose"]
        var workingDir = provider.workingDirectory

        // If inline yamlConfig is provided, persist it to docker-compose.kuma.yml
        if let yamlConfig = provider.yamlConfig?.trimmingCharacters(in: .whitespacesAndNewlines), !yamlConfig.isEmpty {
            let targetDir = (workingDir?.isEmpty == false) ? workingDir! : NSTemporaryDirectory()
            let composeFilePath = (targetDir as NSString).appendingPathComponent("docker-compose.kuma.yml")
            do {
                try yamlConfig.write(toFile: composeFilePath, atomically: true, encoding: .utf8)
                composeArgs.append(contentsOf: ["-f", composeFilePath])
                if workingDir == nil || workingDir?.isEmpty == true {
                    workingDir = targetDir
                }
            } catch {
                throw ServiceExecutionError.processFailed("Failed to write compose YAML: \(error.localizedDescription)")
            }
        }

        composeArgs.append("up")

        let serviceID = service.id
        let serviceName = service.name

        _ = try await processRegistry.launch(
            serviceID: serviceID,
            serviceName: serviceName,
            executable: binaryPath,
            arguments: composeArgs,
            workingDirectory: workingDir,
            onOutput: makeLogPipeline(serviceID: serviceID, serviceName: serviceName)
        )
    }

    // MARK: - SSH Tunnel Runner

    private func startSSH(service: Service, provider: Provider) async throws {
        guard let host = provider.sshHost, !host.isEmpty else {
            throw ServiceExecutionError.invalidConfiguration("SSH Host not configured.")
        }
        let user = provider.sshUser ?? NSUserName()
        let port = provider.sshPort ?? 22
        let portMappings = try await serviceRepository.fetchPortMappings(forService: service.id)

        var args = ["-N", "-p", "\(port)"]
        if let keyPath = provider.sshKeyPath?.trimmingCharacters(in: .whitespacesAndNewlines), !keyPath.isEmpty {
            args.append("-i")
            args.append(keyPath)
        }
        for mapping in portMappings {
            args.append("-L")
            args.append("\(mapping.localPort):localhost:\(mapping.remotePort)")
        }
        args.append("\(user)@\(host)")

        let serviceID = service.id
        let serviceName = service.name

        _ = try await processRegistry.launch(
            serviceID: serviceID,
            serviceName: serviceName,
            executable: "/usr/bin/ssh",
            arguments: args,
            onOutput: makeLogPipeline(serviceID: serviceID, serviceName: serviceName)
        )
    }

    /// Stops a running service process.
    public func stop(serviceID: UUID) async {
        await processRegistry.stop(serviceID: serviceID)
    }

    /// Checks operational state of a service process.
    public func isServiceRunning(serviceID: UUID) async -> Bool {
        await processRegistry.isRunning(serviceID: serviceID)
    }

    // MARK: - Dynamic Pod Pattern Discovery

    private func resolveDynamicPod(
        kubectlPath: String,
        targetPattern: String,
        namespace: String?,
        context: String?,
        customKubeConfigPath: String? = nil,
        serviceID: UUID,
        serviceName: String
    ) async throws -> String {
        LogAggregator.appendLog(
            serviceID: serviceID,
            serviceName: serviceName,
            level: "INFO",
            message: "Discovering active pods matching pattern '\(targetPattern)'..."
        )

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
        defer {
            try? stdoutPipe.fileHandleForReading.close()
            try? stderrPipe.fileHandleForReading.close()
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ServiceExecutionError.processFailed("Failed to execute pod discovery query: \(error.localizedDescription)")
        }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let podNames = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        if podNames.isEmpty {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let errMsg, !errMsg.isEmpty {
                throw ServiceExecutionError.processFailed("Kubectl pod discovery error: \(errMsg)")
            } else {
                throw ServiceExecutionError.processFailed("No running pods found in namespace '\(namespace ?? "default")'.")
            }
        }

        // Match pattern against pod names (supports simple prefix, contains, or wildcard glob)
        let cleanedPattern = targetPattern.replacingOccurrences(of: "*", with: "")

        let matched = podNames.first { name in
            if targetPattern.contains("*") {
                return name.localizedCaseInsensitiveContains(cleanedPattern)
            } else {
                return name == targetPattern || name.hasPrefix(targetPattern) || name.localizedCaseInsensitiveContains(targetPattern)
            }
        }

        guard let targetPod = matched else {
            throw ServiceExecutionError.processFailed("Found \(podNames.count) running pods, but none matched pattern '\(targetPattern)'. Available: \(podNames.prefix(3).joined(separator: ", "))\(podNames.count > 3 ? "..." : "")")
        }

        LogAggregator.appendLog(
            serviceID: serviceID,
            serviceName: serviceName,
            level: "INFO",
            message: "Matched active pod: '\(targetPod)'. Starting port-forward..."
        )

        return targetPod
    }

    /// Releases any orphaned processes holding onto the local port (e.g. from previous app run or crashed terminal session).
    private func killProcessOccupying(port: Int, serviceID: UUID, serviceName: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-ti", ":\(port)"]
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
        }
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                let pids = output.components(separatedBy: .newlines).compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                let currentPID = ProcessInfo.processInfo.processIdentifier

                for pid in pids where pid != currentPID {
                    LogAggregator.appendLog(
                        serviceID: serviceID,
                        serviceName: serviceName,
                        level: "WARN",
                        message: "Port \(port) was held by zombie process (PID \(pid)). Releasing port..."
                    )
                    kill(pid, SIGTERM)
                }

                if !pids.isEmpty {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms socket release window
                }
            }
        } catch {
            Self.logger.debug("lsof check for port \(port) exited: \(error.localizedDescription)")
        }
    }
}
