import Foundation
import os

/// Runner responsible for background HTTP/HTTPS periodic endpoint health checks.
/// Supports normalized URLs (google.com, http://..., https://..., localhost:3000).
public final class HealthCheckRunner: ServiceRunnerProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "HealthCheckRunner")

    private let stateLock = NSLock()
    private var activePollTasks: [UUID: Task<Void, Never>] = [:]

    public nonisolated init() {}

    public func start(
        service: Service,
        provider: Provider,
        pipeline: ServiceLogPipeline
    ) async throws {
        guard let rawUrl = provider.httpCheckUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !rawUrl.isEmpty else {
            throw ServiceExecutionError.invalidConfiguration("Health Check Target URL is not specified.")
        }

        // Smart URL Normalization
        guard let normalizedUrlString = URLNormalizer.normalize(rawUrl),
              let targetURL = URL(string: normalizedUrlString) else {
            throw ServiceExecutionError.invalidConfiguration("Invalid Health Check URL: '\(rawUrl)'. Expected format: google.com, http://..., https://..., or localhost:port")
        }

        let intervalSeconds = max(provider.httpCheckInterval ?? 10, 3)
        let serviceID = service.id

        // Cancel any existing poller for this service
        await stop(serviceID: serviceID)

        await pipeline.emit(level: "INFO", message: "Starting Health Check for: \(normalizedUrlString) (Interval: \(intervalSeconds)s)")

        let task = Task {
            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.timeoutIntervalForRequest = 10
            sessionConfig.timeoutIntervalForResource = 10
            let session = URLSession(configuration: sessionConfig)

            var wasHealthy: Bool? = nil

            while !Task.isCancelled {
                let start = CFAbsoluteTimeGetCurrent()
                do {
                    var request = URLRequest(url: targetURL)
                    request.httpMethod = "GET"
                    request.setValue("Kuma/4.0 HealthCheck", forHTTPHeaderField: "User-Agent")

                    let (_, response) = try await session.data(for: request)
                    let latencyMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

                    if let httpResponse = response as? HTTPURLResponse {
                        let statusCode = httpResponse.statusCode
                        let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                        let isHealthy = (200...399).contains(statusCode)

                        let level = isHealthy ? "INFO" : "WARN"
                        await pipeline.emit(
                            level: level,
                            message: "[HEALTH] GET \(normalizedUrlString) -> \(statusCode) \(statusText) (\(latencyMs)ms)"
                        )

                        let nextState: ServiceState = isHealthy ? .running : .crashed
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .kumaServiceStateChanged,
                                object: serviceID,
                                userInfo: ["state": nextState]
                            )
                        }

                        if wasHealthy == true && !isHealthy && KumaSettingsKey.bool(forKey: KumaSettingsKey.notifyOnCrash, defaultValue: true) {
                            let playSound = KumaSettingsKey.bool(forKey: KumaSettingsKey.notifySound, defaultValue: true)
                            await SystemNotificationCenter.shared.send(
                                .healthCheckFailed(serviceName: service.name, targetUrl: normalizedUrlString),
                                playSound: playSound
                            )
                        }
                        wasHealthy = isHealthy
                    }
                } catch {
                    guard !Task.isCancelled else { break }
                    let latencyMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                    await pipeline.emit(
                        level: "ERROR",
                        message: "[HEALTH] GET \(normalizedUrlString) -> Failed: \(error.localizedDescription) (\(latencyMs)ms)"
                    )

                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .kumaServiceStateChanged,
                            object: serviceID,
                            userInfo: ["state": ServiceState.crashed]
                        )
                    }

                    if wasHealthy != false && KumaSettingsKey.bool(forKey: KumaSettingsKey.notifyOnCrash, defaultValue: true) {
                        let playSound = KumaSettingsKey.bool(forKey: KumaSettingsKey.notifySound, defaultValue: true)
                        await SystemNotificationCenter.shared.send(
                            .healthCheckFailed(serviceName: service.name, targetUrl: normalizedUrlString),
                            playSound: playSound
                        )
                    }
                    wasHealthy = false
                }

                // Sleep interval with cancellation check
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
        guard let task = activePollTasks[serviceID] else { return false }
        return !task.isCancelled
    }

    private func registerTask(_ task: Task<Void, Never>, for serviceID: UUID) {
        stateLock.lock()
        defer { stateLock.unlock() }
        activePollTasks[serviceID] = task
    }

    private func unregisterTask(for serviceID: UUID) -> Task<Void, Never>? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activePollTasks.removeValue(forKey: serviceID)
    }
}
