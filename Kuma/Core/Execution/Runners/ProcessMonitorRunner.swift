import Foundation
import os

/// Runner responsible for watching existing local OS processes by name or binary.
public final class ProcessMonitorRunner: ServiceRunnerProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "ProcessMonitorRunner")

    private let stateLock = NSLock()
    private var activeWatchTasks: [UUID: Task<Void, Never>] = [:]

    public nonisolated init() {}

    public func start(
        service: Service,
        provider: Provider,
        pipeline: ServiceLogPipeline
    ) async throws {
        guard let processName = provider.monitorProcessName?.trimmingCharacters(in: .whitespacesAndNewlines), !processName.isEmpty else {
            throw ServiceExecutionError.invalidConfiguration("Process name to monitor is required (e.g. redis-server, postgres).")
        }

        let intervalSeconds = max(provider.monitorInterval ?? 5, 2)
        let serviceID = service.id

        await stop(serviceID: serviceID)

        await pipeline.emit(level: "INFO", message: "Starting process watchdog for: '\(processName)' (Interval: \(intervalSeconds)s)")

        let task = Task {
            var lastObservedPID: Int32? = nil

            while !Task.isCancelled {
                let currentPID = Self.lookupProcessPID(named: processName)

                if currentPID != lastObservedPID {
                    lastObservedPID = currentPID

                    if let pid = currentPID {
                        await pipeline.emit(level: "INFO", message: "[MONITOR] Process '\(processName)' is RUNNING (PID: \(pid))")
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .kumaServiceStateChanged,
                                object: serviceID,
                                userInfo: ["state": ServiceState.running]
                            )
                        }
                    } else {
                        await pipeline.emit(level: "WARN", message: "[MONITOR] Process '\(processName)' is NOT running")
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .kumaServiceStateChanged,
                                object: serviceID,
                                userInfo: ["state": ServiceState.stopped]
                            )
                        }
                    }
                }

                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
            }
        }

        registerTask(task, for: serviceID)
    }

    public func stop(serviceID: UUID) async {
        let task = unregisterTask(for: serviceID)
        task?.cancel()
        await MainActor.run {
            NotificationCenter.default.post(
                name: .kumaServiceStateChanged,
                object: serviceID,
                userInfo: ["state": ServiceState.stopped]
            )
        }
    }

    public func isRunning(serviceID: UUID) async -> Bool {
        checkIsRunning(serviceID: serviceID)
    }

    private func checkIsRunning(serviceID: UUID) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let task = activeWatchTasks[serviceID] else { return false }
        return !task.isCancelled
    }

    private func registerTask(_ task: Task<Void, Never>, for serviceID: UUID) {
        stateLock.lock()
        defer { stateLock.unlock() }
        activeWatchTasks[serviceID] = task
    }

    private func unregisterTask(for serviceID: UUID) -> Task<Void, Never>? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activeWatchTasks.removeValue(forKey: serviceID)
    }

    private static func lookupProcessPID(named name: String) -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", name]

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
                return pids.first { $0 != currentPID }
            }
        } catch {
            return nil
        }
        return nil
    }
}
