import Foundation

/// Lightweight read-only projection DTO for Service Cards and Table rows.
/// Contains only the essential fields needed for rendering lists without loading heavy Provider details or sensitive configs.
public struct ServiceCardSnapshot: Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let name: String
    public let isDisabled: Bool
    public var isStarred: Bool
    public let subtitle: String
    public let providerCategory: ProviderCategory
    public let portDisplays: [Int]
    public let createdAt: Date
    public let searchKey: String

    public nonisolated init(
        id: UUID,
        name: String,
        isDisabled: Bool = false,
        isStarred: Bool = false,
        subtitle: String = "",
        providerCategory: ProviderCategory = .docker,
        portDisplays: [Int] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isDisabled = isDisabled
        self.isStarred = isStarred
        self.subtitle = subtitle
        self.providerCategory = providerCategory
        self.portDisplays = portDisplays
        self.createdAt = createdAt
        self.searchKey = "\(name) \(subtitle)".lowercased()
    }

    /// Zero-allocation toggle — mutates only isStarred, preserves searchKey without recompute
    public func toggling(starred: Bool) -> Self {
        var copy = self
        copy.isStarred = starred
        return copy
    }
}
