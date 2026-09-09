import Foundation
import os

/// Thread-safe process lifecycle and execution registry.
/// Implements AGENTS.md rules: process group isolation,
/// clean pipe teardown, signal escalation (`SIGINT` -> `SIGTERM` -> `SIGKILL`),
/// and strict Swift 6 Sendable boundary respect.
public actor ProcessRegistry {
    public static let shared = ProcessRegistry()
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ProcessRegistry")

    private static let stateLock = NSLock()
    nonisolated(unsafe) private static var _cachedActiveServiceIDs: [UUID] = []

    /// Thread-safe synchronous access to active running service IDs from any context (e.g. AppDelegate)
    public nonisolated static var activeRunningServiceIDs: [UUID] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _cachedActiveServiceIDs
    }

    private static func syncActiveIDs(_ ids: [UUID]) {
        stateLock.lock()
        defer { stateLock.unlock() }
        _cachedActiveServiceIDs = ids
    }

    public struct ProcessSnapshot: Sendable, Equatable {
        public let serviceID: UUID
        public let pid: pid_t
        public let pgid: pid_t
        public let startTime: Date
    }

    private final class ManagedProcess {
        let serviceID: UUID
        let serviceName: String
        let process: Process
        let pgid: pid_t
        let startTime: Date
        let onOutput: (@Sendable (String) -> Void)?
        var stdoutPipe: Pipe?
        var stderrPipe: Pipe?

        init(
            serviceID: UUID,
            serviceName: String,
            process: Process,
            pgid: pid_t,
            startTime: Date,
            stdoutPipe: Pipe?,
            stderrPipe: Pipe?,
            onOutput: (@Sendable (String) -> Void)?
        ) {
            self.serviceID = serviceID
            self.serviceName = serviceName
            self.process = process
            self.pgid = pgid
            self.startTime = startTime
            self.stdoutPipe = stdoutPipe
            self.stderrPipe = stderrPipe
            self.onOutput = onOutput
        }

        func cleanupPipes(drainRemaining: Bool = false) {
            if let stdout = stdoutPipe {
                stdout.fileHandleForReading.readabilityHandler = nil
                if drainRemaining {
                    let remaining = stdout.fileHandleForReading.readDataToEndOfFile()
                    if !remaining.isEmpty, let text = String(data: remaining, encoding: .utf8) {
                        onOutput?(text)
                    }
                }
                try? stdout.fileHandleForReading.close()
            }
            if let stderr = stderrPipe {
                stderr.fileHandleForReading.readabilityHandler = nil
                if drainRemaining {
                    let remaining = stderr.fileHandleForReading.readDataToEndOfFile()
                    if !remaining.isEmpty, let text = String(data: remaining, encoding: .utf8) {
                        onOutput?(text)
                    }
                }
                try? stderr.fileHandleForReading.close()
            }
            stdoutPipe = nil
            stderrPipe = nil
        }
    }

    private var activeProcesses: [UUID: ManagedProcess] = [:]

    private init() {}

    /// Launches an external executable under an isolated process group.
    public func launch(
        serviceID: UUID,
        serviceName: String = "Service",
        executable: String,
        arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> pid_t {
        // Stop any existing process for this service first
        if activeProcesses[serviceID] != nil {
            await stop(serviceID: serviceID)
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

        // Setup pipe readability handlers BEFORE run() so early output is never missed
        setupPipeHandler(pipe: stdoutPipe, serviceID: serviceID, onOutput: onOutput)
        setupPipeHandler(pipe: stderrPipe, serviceID: serviceID, onOutput: onOutput)

        try process.run()

        let pid = process.processIdentifier
        // Assign separate process group to isolate signals.
        // On macOS, if the child process exited immediately, setpgid may return -1 with ESRCH or EACCES.
        if setpgid(pid, pid) != 0 {
            let err = errno
            if err != ESRCH && err != EACCES {
                Self.logger.debug("setpgid failed for PID \(pid): errno \(err)")
            }
        }

        let managed = ManagedProcess(
            serviceID: serviceID,
            serviceName: serviceName,
            process: process,
            pgid: pid,
            startTime: Date(),
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe,
            onOutput: onOutput
        )
        activeProcesses[serviceID] = managed
        Self.syncActiveIDs(Array(activeProcesses.keys))

        Self.logger.info("Launched process for service \(serviceName) (\(serviceID)) (PID: \(pid), PGID: \(pid))")

        // Setup clean termination observer
        process.terminationHandler = { [weak self] proc in
            let exitCode = proc.terminationStatus
            let reason = proc.terminationReason
            Self.logger.info("Process for service \(serviceName) (\(serviceID)) terminated with code \(exitCode) (reason: \(reason == .exit ? "exit" : "uncaughtSignal"))")

            Task { [weak self] in
                await self?.handleProcessTerminated(serviceID: serviceID, exitCode: exitCode)
            }
        }

        return pid
    }

    private func handleProcessTerminated(serviceID: UUID, exitCode: Int32) async {
        guard let managed = activeProcesses.removeValue(forKey: serviceID) else { return }
        Self.syncActiveIDs(Array(activeProcesses.keys))
        managed.cleanupPipes(drainRemaining: true)

        let state: ServiceState = (exitCode == 0) ? .stopped : .crashed
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .kumaServiceStateChanged,
                object: serviceID,
                userInfo: ["state": state]
            )
        }

        // Send macOS system notification if crashed and notifyOnCrash is enabled
        if exitCode != 0 && KumaSettingsKey.bool(forKey: KumaSettingsKey.notifyOnCrash, defaultValue: true) {
            let playSound = KumaSettingsKey.bool(forKey: KumaSettingsKey.notifySound, defaultValue: true)
            await SystemNotificationCenter.shared.send(
                .serviceCrash(serviceName: managed.serviceName, reason: "Exited with code \(exitCode)"),
                playSound: playSound
            )
        }
    }

    /// Stops a running service process with progressive signal escalation.
    /// Sends SIGINT first, waits up to 1.5s, escalates to SIGTERM, waits 1.0s, and finally SIGKILL.
    /// Pipes are kept open during shutdown to capture any final exit logs before being closed.
    public func stop(serviceID: UUID) async {
        guard let managed = activeProcesses[serviceID] else { return }
        let pgid = managed.pgid
        let process = managed.process

        Self.logger.info("Stopping process for service \(serviceID) (PGID: \(pgid))...")

        // 1. Graceful SIGINT to process group
        kill(-pgid, SIGINT)

        // Wait up to 1.5s for clean exit
        for _ in 0..<15 {
            if !process.isRunning { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 2. Escalate to SIGTERM if still alive
        if process.isRunning {
            Self.logger.warning("Process \(pgid) still running after SIGINT. Escalating to SIGTERM.")
            kill(-pgid, SIGTERM)

            // Wait up to 1.0s
            for _ in 0..<10 {
                if !process.isRunning { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        // 3. Final escalation to SIGKILL if stubborn
        if process.isRunning {
            Self.logger.error("Process \(pgid) still running after SIGTERM. Sending SIGKILL.")
            kill(-pgid, SIGKILL)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Cleanup tracking and pipes
        if let removed = activeProcesses.removeValue(forKey: serviceID) {
            Self.syncActiveIDs(Array(activeProcesses.keys))
            removed.cleanupPipes(drainRemaining: true)
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

    /// Batch queries execution states for a list of service IDs in a single actor crossing.
    public func runningStates(for serviceIDs: [UUID]) -> [UUID: ServiceExecutionState] {
        var result: [UUID: ServiceExecutionState] = [:]
        result.reserveCapacity(serviceIDs.count)

        for id in serviceIDs {
            if let managed = activeProcesses[id], managed.process.isRunning {
                result[id] = .running(pid: managed.process.processIdentifier)
            } else {
                result[id] = .idle
            }
        }
        return result
    }

    /// Returns list of all service IDs currently running active child processes.
    public func activeRunningServiceIDs() -> [UUID] {
        activeProcesses.values
            .filter { $0.process.isRunning }
            .map { $0.serviceID }
    }

    /// Gracefully escalates termination for all tracked child processes (SIGTERM -> SIGKILL) and cleans up pipes without blocking.
    public func terminateAll() {
        // 1. Send SIGTERM first to allow child processes to teardown gracefully
        for (_, managed) in activeProcesses {
            let pgid = managed.pgid
            kill(-pgid, SIGTERM)
        }

        // 2. Short non-blocking grace period (up to 200ms) for clean exit
        for _ in 0..<2 {
            let anyRunning = activeProcesses.values.contains { $0.process.isRunning }
            if !anyRunning { break }
            usleep(100_000)
        }

        // 3. SIGKILL any processes still alive and close pipes immediately without blocking
        for (_, managed) in activeProcesses {
            let pgid = managed.pgid
            if managed.process.isRunning {
                kill(-pgid, SIGKILL)
            }
            managed.cleanupPipes(drainRemaining: false)
        }
        activeProcesses.removeAll()
        Self.syncActiveIDs([])
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
