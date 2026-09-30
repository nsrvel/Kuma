import Foundation

/// Immutable identity for a `docker|podman compose` stack managed by Kuma.
public nonisolated struct ComposeStackContext: Sendable, Equatable {
    public let serviceID: UUID
    public let binaryPath: String
    public let composeFilePath: String
    public let workingDirectory: String
    public let projectName: String
    public let isEphemeralComposeFile: Bool

    public nonisolated init(
        serviceID: UUID,
        binaryPath: String,
        composeFilePath: String,
        workingDirectory: String,
        projectName: String,
        isEphemeralComposeFile: Bool
    ) {
        self.serviceID = serviceID
        self.binaryPath = binaryPath
        self.composeFilePath = composeFilePath
        self.workingDirectory = workingDirectory
        self.projectName = projectName
        self.isEphemeralComposeFile = isEphemeralComposeFile
    }

    /// Stable Compose project name so `up` / `stop` / `down` always target the same stack.
    public nonisolated static func projectName(for serviceID: UUID) -> String {
        let compact = serviceID.uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        return "kuma-\(compact)"
    }

    public nonisolated func arguments(subcommand: [String]) -> [String] {
        ["compose", "-p", projectName, "-f", composeFilePath] + subcommand
    }

    public nonisolated var upArguments: [String] {
        arguments(subcommand: ["up", "-d", "--remove-orphans"])
    }

    public nonisolated var stopArguments: [String] {
        arguments(subcommand: ["stop", "--timeout", "5"])
    }

    public nonisolated var downArguments: [String] {
        arguments(subcommand: ["down", "--timeout", "5", "--remove-orphans"])
    }

    public nonisolated var psQuietArguments: [String] {
        arguments(subcommand: ["ps", "-q", "--status", "running"])
    }
}
