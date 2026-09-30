import Foundation
import os

/// Runner responsible for arbitrary shell script execution in an isolated macOS zsh environment.
public final class ShellRunner: ServiceRunnerProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ShellRunner")

    private let processRegistry: ProcessRegistry

    public nonisolated init(processRegistry: ProcessRegistry = .shared) {
        self.processRegistry = processRegistry
    }

    public func start(
        service: Service,
        provider: Provider,
        pipeline: ServiceLogPipeline
    ) async throws {
        guard let runCommand = provider.runCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !runCommand.isEmpty else {
            throw ServiceExecutionError.invalidConfiguration("No shell command specified.")
        }

        // Expand working directory tilde (~/...) if configured
        var resolvedDir: String? = nil
        if let rawDir = provider.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines), !rawDir.isEmpty {
            resolvedDir = NSString(string: rawDir).expandingTildeInPath
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: resolvedDir!, isDirectory: &isDir) || !isDir.boolValue {
                throw ServiceExecutionError.invalidConfiguration("Working directory does not exist: '\(rawDir)'")
            }
        }

        // Enrich environment with resolved shell PATH
        let fullPath = await EnvironmentPathResolver.shared.resolvePath()
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = fullPath

        await pipeline.emit(level: "INFO", message: "Executing command: \(runCommand)")
        if let resolvedDir {
            await pipeline.emit(level: "INFO", message: "Working directory: \(resolvedDir)")
        }

        let bootstrapCommand = "[ -f ~/.zprofile ] && source ~/.zprofile 2>/dev/null; [ -f ~/.zshrc ] && source ~/.zshrc 2>/dev/null; [ -f ~/.bash_profile ] && source ~/.bash_profile 2>/dev/null; eval \"$1\""

        _ = try await processRegistry.launch(
            serviceID: service.id,
            serviceName: service.name,
            executable: "/bin/zsh",
            arguments: ["-c", bootstrapCommand, "--", runCommand],
            workingDirectory: resolvedDir,
            environment: env,
            onOutput: pipeline.makeOutputHandler()
        )
    }

    public func stop(serviceID: UUID) async {
        await processRegistry.stop(serviceID: serviceID)
    }

    public func isRunning(serviceID: UUID) async -> Bool {
        await processRegistry.isRunning(serviceID: serviceID)
    }
}
