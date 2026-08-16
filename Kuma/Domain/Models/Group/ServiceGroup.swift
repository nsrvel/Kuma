import Foundation

public struct ServiceGroup: Identifiable, Codable, Equatable, Sendable, Hashable {
    public var id: UUID
    public var workspaceID: UUID
    public var name: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        workspaceID: UUID,
        name: String,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
