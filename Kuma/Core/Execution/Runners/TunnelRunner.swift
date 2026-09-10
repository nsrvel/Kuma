import Foundation
import os

/// Runner responsible for public tunneling via Cloudflare Tunnel (`cloudflared`) or Ngrok.
public final class TunnelRunner: ServiceRunnerProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "TunnelRunner")

    private let processRegistry: ProcessRegistry

    public nonisolated init(processRegistry: ProcessRegistry = .shared) {
        self.processRegistry = processRegistry
    }

    public func start(
        service: Service,
        provider: Provider,
        pipeline: ServiceLogPipeline
    ) async throws {
        let engine = provider.tunnelType?.lowercased() ?? "cloudflare"

        guard let rawTarget = provider.tunnelTargetUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !rawTarget.isEmpty else {
            throw ServiceExecutionError.invalidConfiguration("Tunnel target (port or local URL) is required.")
        }

        let normalizedTarget = URLNormalizer.normalize(rawTarget, defaultToHttps: false) ?? "http://localhost:3000"

        if engine == "ngrok" {
            try await startNgrok(service: service, provider: provider, target: normalizedTarget, pipeline: pipeline)
        } else {
            try await startCloudflare(service: service, provider: provider, target: normalizedTarget, pipeline: pipeline)
        }
    }

    public func stop(serviceID: UUID) async {
        await processRegistry.stop(serviceID: serviceID)
    }

    public func isRunning(serviceID: UUID) async -> Bool {
        await processRegistry.isRunning(serviceID: serviceID)
    }

    // MARK: - Cloudflare Tunnel

    private func startCloudflare(
        service: Service,
        provider: Provider,
        target: String,
        pipeline: ServiceLogPipeline
    ) async throws {
        guard let binaryPath = await EnvironmentPathResolver.shared.resolveExecutablePath(for: "cloudflared") else {
            throw ServiceExecutionError.binaryNotFound("cloudflared")
        }

        await pipeline.emit(level: "INFO", message: "Starting Cloudflare Tunnel to \(target)...")

        let args = ["tunnel", "--url", target, "--no-autoupdate"]

        // Custom output wrapper that detects trycloudflare URL
        let baseHandler = pipeline.makeOutputHandler()
        let tryCloudflareRegex = try? NSRegularExpression(pattern: #"https://[a-zA-Z0-9-]+\.trycloudflare\.com"#, options: [])

        let onOutput: @Sendable (String) -> Void = { text in
            baseHandler(text)

            if let regex = tryCloudflareRegex {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let r = Range(match.range, in: text) {
                    let publicUrl = String(text[r])
                    Task {
                        await pipeline.emit(level: "INFO", message: "[TUNNEL] Public Tunnel URL: \(publicUrl)")
                    }
                }
            }
        }

        _ = try await processRegistry.launch(
            serviceID: service.id,
            serviceName: service.name,
            executable: binaryPath,
            arguments: args,
            onOutput: onOutput
        )
    }

    // MARK: - Ngrok Tunnel

    private func startNgrok(
        service: Service,
        provider: Provider,
        target: String,
        pipeline: ServiceLogPipeline
    ) async throws {
        guard let binaryPath = await EnvironmentPathResolver.shared.resolveExecutablePath(for: "ngrok") else {
            throw ServiceExecutionError.binaryNotFound("ngrok")
        }

        var args = ["http", target]

        if var token = provider.ngrokAuthToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            if token.starts(with: "vault:") {
                token = (try? CryptoVault.shared.decrypt(cipherText: token)) ?? token
            }
            args.append(contentsOf: ["--authtoken", token])
        }

        await pipeline.emit(level: "INFO", message: "Starting Ngrok Tunnel to \(target)...")

        _ = try await processRegistry.launch(
            serviceID: service.id,
            serviceName: service.name,
            executable: binaryPath,
            arguments: args,
            onOutput: pipeline.makeOutputHandler()
        )
    }
}
