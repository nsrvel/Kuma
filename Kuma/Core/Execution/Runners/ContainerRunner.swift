import Foundation
import os

/// Runner responsible for container orchestration with Docker or Podman Compose.
public final class ContainerRunner: ServiceRunnerProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ContainerRunner")

    private let processRegistry: ProcessRegistry
    private let stateLock = NSLock()
    private var activeComposeFiles: [UUID: String] = [:]
    private var activeBinaryPaths: [UUID: String] = [:]

    public nonisolated init(processRegistry: ProcessRegistry = .shared) {
        self.processRegistry = processRegistry
    }

    public func start(
        service: Service,
        provider: Provider,
        pipeline: ServiceLogPipeline
    ) async throws {
        let binaryName = provider.type == .docker ? "docker" : "podman"
        guard let binaryPath = await EnvironmentPathResolver.shared.resolveExecutablePath(for: binaryName) else {
            throw ServiceExecutionError.binaryNotFound(binaryName)
        }

        var workingDir: String? = nil
        if let rawDir = provider.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines), !rawDir.isEmpty {
            let expanded = NSString(string: rawDir).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                workingDir = expanded
            }
        }

        var composeArgs = ["compose"]
        var composeFilePath: String? = nil

        // If inline yamlConfig is provided, persist it to disk with service isolation
        if let yamlConfig = provider.yamlConfig?.trimmingCharacters(in: .whitespacesAndNewlines), !yamlConfig.isEmpty {
            let targetDir: String
            if let workingDir {
                targetDir = workingDir
            } else {
                let tempFolder = (NSTemporaryDirectory() as NSString).appendingPathComponent("kuma-compose-\(service.id.uuidString)")
                try? FileManager.default.createDirectory(atPath: tempFolder, withIntermediateDirectories: true)
                targetDir = tempFolder
                workingDir = tempFolder
            }

            let filePath = (targetDir as NSString).appendingPathComponent("docker-compose.kuma.yml")
            do {
                try yamlConfig.write(toFile: filePath, atomically: true, encoding: .utf8)
                composeFilePath = filePath
                composeArgs.append(contentsOf: ["-f", filePath])
            } catch {
                throw ServiceExecutionError.processFailed("Failed to write compose YAML: \(error.localizedDescription)")
            }
        }

        registerActive(serviceID: service.id, binary: binaryPath, composeFile: composeFilePath)

        // Execute initial setup script if configured
        if let initialScript = provider.initialScript?.trimmingCharacters(in: .whitespacesAndNewlines), !initialScript.isEmpty {
            await pipeline.emit(level: "INFO", message: "Running pre-start initialization script...")
            await executeScript(initialScript, workingDir: workingDir, pipeline: pipeline)
        }

        composeArgs.append("up")
        await pipeline.emit(level: "INFO", message: "Starting \(binaryName) compose up...")

        _ = try await processRegistry.launch(
            serviceID: service.id,
            serviceName: service.name,
            executable: binaryPath,
            arguments: composeArgs,
            workingDirectory: workingDir,
            onOutput: pipeline.makeOutputHandler()
        )
    }

    public func stop(serviceID: UUID) async {
        // 1. Stop attached client process
        await processRegistry.stop(serviceID: serviceID)

        // 2. Run background `compose down` to tear down containers cleanly
        let active = unregisterActive(serviceID: serviceID)

        if let binary = active.binary {
            var downArgs = ["compose"]
            if let composeFile = active.composeFile {
                downArgs.append(contentsOf: ["-f", composeFile])
            }
            downArgs.append("down")

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: binary)
            proc.arguments = downArgs
            try? proc.run()
            proc.waitUntilExit()

            // Cleanup ephemeral temp compose directory if applicable
            if let composeFile = active.composeFile, composeFile.contains("kuma-compose-\(serviceID.uuidString)") {
                let folder = (composeFile as NSString).deletingLastPathComponent
                try? FileManager.default.removeItem(atPath: folder)
            }
        }
    }

    public func isRunning(serviceID: UUID) async -> Bool {
        await processRegistry.isRunning(serviceID: serviceID)
    }

    private func registerActive(serviceID: UUID, binary: String, composeFile: String?) {
        stateLock.lock()
        defer { stateLock.unlock() }
        activeBinaryPaths[serviceID] = binary
        if let composeFile {
            activeComposeFiles[serviceID] = composeFile
        }
    }

    private func unregisterActive(serviceID: UUID) -> (binary: String?, composeFile: String?) {
        stateLock.lock()
        defer { stateLock.unlock() }
        let binary = activeBinaryPaths.removeValue(forKey: serviceID)
        let compose = activeComposeFiles.removeValue(forKey: serviceID)
        return (binary, compose)
    }

    private func executeScript(_ script: String, workingDir: String?, pipeline: ServiceLogPipeline) async {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let bootstrap = "[ -f ~/.zprofile ] && source ~/.zprofile 2>/dev/null; [ -f ~/.zshrc ] && source ~/.zshrc 2>/dev/null; [ -f ~/.bash_profile ] && source ~/.bash_profile 2>/dev/null; eval \"$1\""
        proc.arguments = ["-c", bootstrap, "--", script]
        if let workingDir {
            proc.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }

        let pipe = Pipe()
        defer { try? pipe.fileHandleForReading.close() }
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            processRegistryWait(proc)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                await pipeline.emit(level: "INFO", message: output)
            }
        } catch {
            await pipeline.emit(level: "WARN", message: "Initial script failed: \(error.localizedDescription)")
        }
    }

    private func processRegistryWait(_ proc: Process) {
        proc.waitUntilExit()
    }
}
