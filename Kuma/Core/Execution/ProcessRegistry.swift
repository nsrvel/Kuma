import Foundation
import os

/// Thread-safe process lifecycle and execution registry.
/// Implements AGENTS.md rules: `setpgid(0, 0)`, process group isolation,
/// output aggregation, and orphan killer escalation (`SIGINT` -> `SIGTERM` -> `SIGKILL`).
public actor ProcessRegistry {
    public static let shared = ProcessRegistry()
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ProcessRegistry")

    public struct ProcessInfo: Sendable {
        public let serviceID: UUID
        public let process: Process
        public let pgid: pid_t
        public let startTime: Date
    }

    private var activeProcesses: [UUID: ProcessInfo] = [:]

    private init() {}

    /// Registers and launches a process under an isolated process group (`setpgid(0, 0)`).
    public func launch(
        serviceID: UUID,
        executable: String,
        arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) throws -> pid_t {
        // Stop any existing process for this service first
        if activeProcesses[serviceID] != nil {
            stop(serviceID: serviceID)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let workingDirectory, !workingDirectory.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        if let environment {
            var currentEnv = Foundation.ProcessInfo.processInfo.environment
            for (k, v) in environment {
                currentEnv[k] = v
            }
            process.environment = currentEnv
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.qualityOfService = .userInitiated

        try process.run()

        let pid = process.processIdentifier
        // Assign separate process group to isolate signals
        setpgid(pid, pid)

        let info = ProcessInfo(serviceID: serviceID, process: process, pgid: pid, startTime: Date())
        activeProcesses[serviceID] = info

        Self.logger.info("Launched process for service \(serviceID) (PID: \(pid), PGID: \(pid))")

        // Asynchronously read stdout and stderr
        listenToPipe(pipe: stdoutPipe, serviceID: serviceID, onOutput: onOutput)
        listenToPipe(pipe: stderrPipe, serviceID: serviceID, onOutput: onOutput)

        return pid
    }

    /// Stops a running service process with progressive signal escalation.
    public func stop(serviceID: UUID) {
        guard let info = activeProcesses.removeValue(forKey: serviceID) else { return }
        let pgid = info.pgid
        let process = info.process

        Self.logger.info("Stopping service \(serviceID) (PGID: \(pgid))...")

        // 1. SIGINT to process group
        kill(-pgid, SIGINT)

        Task.detached(priority: .userInitiated) {
            // Wait 1.5s for clean shutdown
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if process.isRunning {
                Self.logger.warning("Process \(pgid) still running after SIGINT. Escalating to SIGTERM.")
                kill(-pgid, SIGTERM)

                // Wait 1.0s more
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if process.isRunning {
                    Self.logger.error("Process \(pgid) still running after SIGTERM. Sending SIGKILL.")
                    kill(-pgid, SIGKILL)
                }
            }
        }
    }

    /// Checks if a service process is currently active and running.
    public func isRunning(serviceID: UUID) -> Bool {
        guard let info = activeProcesses[serviceID] else { return false }
        return info.process.isRunning
    }

    /// Returns process ID for a running service.
    public func getPID(serviceID: UUID) -> pid_t? {
        guard let info = activeProcesses[serviceID], info.process.isRunning else { return nil }
        return info.pgid
    }

    /// Terminates all tracked child processes immediately (app shutdown guard).
    public func terminateAll() {
        for (serviceID, _) in activeProcesses {
            stop(serviceID: serviceID)
        }
        activeProcesses.removeAll()
    }

    private func listenToPipe(
        pipe: Pipe,
        serviceID: UUID,
        onOutput: (@Sendable (String) -> Void)?
    ) {
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onOutput?(text)
        }
    }
}
