import Darwin
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

    private enum SignalTarget: Sendable {
        case processGroup(pgid: pid_t)
        case singleProcess(pid: pid_t)

        func send(_ signal: Int32) {
            switch self {
            case .processGroup(let pgid):
                kill(-pgid, signal)
            case .singleProcess(let pid):
                kill(pid, signal)
            }
        }
    }

    private final class ManagedProcess {
        let serviceID: UUID
        let serviceName: String
        let process: Process
        let pgid: pid_t
        let signalTarget: SignalTarget
        let startTime: Date
        init(
            serviceID: UUID,
            serviceName: String,
            process: Process,
            pgid: pid_t,
            signalTarget: SignalTarget,
            startTime: Date
        ) {
            self.serviceID = serviceID
            self.serviceName = serviceName
            self.process = process
            self.pgid = pgid
            self.signalTarget = signalTarget
            self.startTime = startTime
        }
    }

    private var activeProcesses: [UUID: ManagedProcess] = [:]
    /// Services we are stopping via `stop()` — termination should not be treated as a user-visible crash.
    private var intentionallyStopping: Set<UUID> = []

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
        _ = onOutput
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

        process.qualityOfService = .userInitiated
        let spoolFD = try RunSpool.openAppendFD(for: serviceID)
        let stdoutHandle = FileHandle(fileDescriptor: spoolFD, closeOnDealloc: false)
        let stderrFD = dup(spoolFD)
        process.standardOutput = stdoutHandle
        if stderrFD >= 0 {
            process.standardError = FileHandle(fileDescriptor: stderrFD, closeOnDealloc: true)
        } else {
            process.standardError = stdoutHandle
        }

        try process.run()
        try? stdoutHandle.close()

        let pid = process.processIdentifier
        let signalTarget: SignalTarget
        if setpgid(pid, pid) == 0 {
            signalTarget = .processGroup(pgid: pid)
        } else {
            let err = errno
            if err != ESRCH && err != EACCES {
                Self.logger.debug("setpgid failed for PID \(pid): errno \(err); using single-process signals")
            }
            signalTarget = .singleProcess(pid: pid)
        }

        let startedAt = Date()
        let managed = ManagedProcess(
            serviceID: serviceID,
            serviceName: serviceName,
            process: process,
            pgid: pid,
            signalTarget: signalTarget,
            startTime: startedAt
        )
        activeProcesses[serviceID] = managed
        Self.syncActiveIDs(Array(activeProcesses.keys))

        Self.logger.info("Launched process for service \(serviceName) (\(serviceID)) (PID: \(pid), PGID: \(pid))")

        await ExecutionSupervisor.shared.register(
            .managedProcess(serviceID: serviceID, serviceName: serviceName, pid: pid, startedAt: startedAt)
        )

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
        let wasIntentionalStop = intentionallyStopping.remove(serviceID) != nil
        guard let managed = activeProcesses.removeValue(forKey: serviceID) else { return }
        Self.syncActiveIDs(Array(activeProcesses.keys))
        await ExecutionSupervisor.shared.handleManagedProcessExit(
            serviceID: serviceID,
            serviceName: managed.serviceName,
            exitCode: exitCode,
            intentionalStop: wasIntentionalStop
        )
    }

    /// Stops a running service process with progressive signal escalation.
    /// Sends SIGINT first, waits up to 1.5s, escalates to SIGTERM, waits 1.0s, and finally SIGKILL.
    /// Pipes are kept open during shutdown to capture any final exit logs before being closed.
    public func stop(serviceID: UUID) async {
        guard let managed = activeProcesses[serviceID] else { return }
        intentionallyStopping.insert(serviceID)
        let process = managed.process

        Self.logger.info("Stopping process for service \(serviceID) (PID: \(process.processIdentifier))...")

        managed.signalTarget.send(SIGINT)

        for _ in 0..<15 {
            if !process.isRunning { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if process.isRunning {
            Self.logger.warning("Process \(process.processIdentifier) still running after SIGINT. Escalating to SIGTERM.")
            managed.signalTarget.send(SIGTERM)

            for _ in 0..<10 {
                if !process.isRunning { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        if process.isRunning {
            Self.logger.error("Process \(process.processIdentifier) still running after SIGTERM. Sending SIGKILL.")
            managed.signalTarget.send(SIGKILL)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if activeProcesses[serviceID] != nil {
            let exitCode = process.isRunning ? SIGKILL : process.terminationStatus
            await handleProcessTerminated(serviceID: serviceID, exitCode: exitCode)
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

    public func serviceName(forPID pid: pid_t) -> String? {
        for managed in activeProcesses.values where managed.process.isRunning && managed.process.processIdentifier == pid {
            return managed.serviceName
        }
        return nil
    }

    public func serviceID(forPID pid: pid_t) -> UUID? {
        for managed in activeProcesses.values where managed.process.isRunning && managed.process.processIdentifier == pid {
            return managed.serviceID
        }
        return nil
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
            managed.signalTarget.send(SIGTERM)
        }

        // 2. Short non-blocking grace period (up to 200ms) for clean exit
        for _ in 0..<2 {
            let anyRunning = activeProcesses.values.contains { $0.process.isRunning }
            if !anyRunning { break }
            usleep(100_000)
        }

        // 3. SIGKILL any processes still alive and close pipes immediately without blocking
        for (_, managed) in activeProcesses {
            if managed.process.isRunning {
                managed.signalTarget.send(SIGKILL)
            }
        }
        activeProcesses.removeAll()
        Self.syncActiveIDs([])
    }

    public func terminateAllAsync() async {
        terminateAll()
    }
}
