import Foundation

public struct Service: Identifiable, Codable, Equatable, Sendable, Hashable {
    public var id: UUID
    public var name: String
    public var icon: String?
    public var colorHex: String?
    public var description: String?
    public var activeProviderID: UUID?
    public var workspaceID: UUID?
    public var isDisabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        icon: String? = nil,
        colorHex: String? = nil,
        description: String? = nil,
        activeProviderID: UUID? = nil,
        workspaceID: UUID? = nil,
        isDisabled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.description = description
        self.activeProviderID = activeProviderID
        self.workspaceID = workspaceID
        self.isDisabled = isDisabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
