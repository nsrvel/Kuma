import Foundation
import os

/// Thread-safe process lifecycle and execution registry.
/// Implements AGENTS.md rules: process group isolation,
/// clean pipe teardown, signal escalation (`SIGINT` -> `SIGTERM` -> `SIGKILL`),
/// and strict Swift 6 Sendable boundary respect.
public actor ProcessRegistry {
    public static let shared = ProcessRegistry()
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ProcessRegistry")

    public struct ProcessSnapshot: Sendable, Equatable {
        public let serviceID: UUID
        public let pid: pid_t
        public let pgid: pid_t
        public let startTime: Date
    }

    private final class ManagedProcess {
        let serviceID: UUID
        let process: Process
        let pgid: pid_t
        let startTime: Date
        var stdoutPipe: Pipe?
        var stderrPipe: Pipe?

        init(serviceID: UUID, process: Process, pgid: pid_t, startTime: Date, stdoutPipe: Pipe?, stderrPipe: Pipe?) {
            self.serviceID = serviceID
            self.process = process
            self.pgid = pgid
            self.startTime = startTime
            self.stdoutPipe = stdoutPipe
            self.stderrPipe = stderrPipe
        }

        func cleanupPipes() {
            stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            stderrPipe?.fileHandleForReading.readabilityHandler = nil
            try? stdoutPipe?.fileHandleForReading.close()
            try? stderrPipe?.fileHandleForReading.close()
            stdoutPipe = nil
            stderrPipe = nil
        }
    }

    private var activeProcesses: [UUID: ManagedProcess] = [:]

    private init() {}

    /// Launches an external executable under an isolated process group.
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

        let managed = ManagedProcess(
            serviceID: serviceID,
            process: process,
            pgid: pid,
            startTime: Date(),
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe
        )
        activeProcesses[serviceID] = managed

        Self.logger.info("Launched process for service \(serviceID) (PID: \(pid), PGID: \(pid))")

        // Setup clean termination observer
        process.terminationHandler = { [weak self] proc in
            let exitCode = proc.terminationStatus
            let reason = proc.terminationReason
            Self.logger.info("Process for service \(serviceID) terminated with code \(exitCode) (reason: \(reason == .exit ? "exit" : "uncaughtSignal"))")

            Task { [weak self] in
                await self?.handleProcessTerminated(serviceID: serviceID, exitCode: exitCode)
            }
        }

        // Asynchronously read stdout and stderr via readabilityHandler
        setupPipeHandler(pipe: stdoutPipe, serviceID: serviceID, onOutput: onOutput)
        setupPipeHandler(pipe: stderrPipe, serviceID: serviceID, onOutput: onOutput)

        return pid
    }

    private func handleProcessTerminated(serviceID: UUID, exitCode: Int32) {
        guard let managed = activeProcesses.removeValue(forKey: serviceID) else { return }
        managed.cleanupPipes()

        let state: ServiceState = (exitCode == 0) ? .stopped : .crashed
        NotificationCenter.default.post(
            name: .kumaServiceStateChanged,
            object: serviceID,
            userInfo: ["state": state]
        )
    }

    /// Stops a running service process with progressive signal escalation.
    public func stop(serviceID: UUID) {
        guard let managed = activeProcesses.removeValue(forKey: serviceID) else { return }
        let pgid = managed.pgid
        let process = managed.process
        managed.cleanupPipes()

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
        guard let managed = activeProcesses[serviceID] else { return false }
        return managed.process.isRunning
    }

    /// Returns process snapshot for a running service.
    public func getSnapshot(serviceID: UUID) -> ProcessSnapshot? {
        guard let managed = activeProcesses[serviceID], managed.process.isRunning else { return nil }
        return ProcessSnapshot(
            serviceID: serviceID,
            pid: managed.process.processIdentifier,
            pgid: managed.pgid,
            startTime: managed.startTime
        )
    }

    /// Terminates all tracked child processes immediately via SIGKILL (app shutdown guard).
    public func terminateAll() {
        for (_, managed) in activeProcesses {
            let pgid = managed.pgid
            managed.cleanupPipes()
            kill(-pgid, SIGKILL)
        }
        activeProcesses.removeAll()
    }

    private func setupPipeHandler(
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
