import Foundation

/// Unified protocol for runner engines powering specific provider categories in Kuma.
/// Implementations handle subprocesses (Kubernetes, Shell, Docker, Podman, SSH, Tunnel)
/// or background polling tasks (Health Check, Process Monitor).
public protocol ServiceRunnerProtocol: Sendable {
    /// Starts execution of a service using the specified provider configuration.
    func start(
        service: Service,
        provider: Provider,
        pipeline: ServiceLogPipeline
    ) async throws

    /// Stops any running process or background polling task associated with the service.
    func stop(serviceID: UUID) async

    /// Queries whether the service is currently running under this runner.
    func isRunning(serviceID: UUID) async -> Bool
}
