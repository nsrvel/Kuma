import Foundation

// MARK: - KubeConfig Domain Model

public nonisolated struct KubeConfig: Identifiable, Codable, Sendable, Equatable, Hashable {
    /// Reserved static ID for the system default kubeconfig (~/.kube/config)
    public nonisolated static let defaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public var id: UUID
    public var name: String
    public var configContent: String // YAML content
    public var isDefault: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        configContent: String,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.configContent = configContent
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
