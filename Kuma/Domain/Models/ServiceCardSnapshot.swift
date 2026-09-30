import Foundation

/// Lightweight read-only projection DTO for Service Cards and Table rows.
/// Contains only the essential fields needed for rendering lists without loading heavy Provider details or sensitive configs.
public nonisolated struct ServiceCardSnapshot: Identifiable, Sendable, Equatable, Hashable {
    public nonisolated struct ProviderOption: Identifiable, Sendable, Equatable, Hashable {
        public let id: UUID
        public let category: ProviderCategory
        public let label: String
        public let isActive: Bool

        public nonisolated init(id: UUID, category: ProviderCategory, label: String, isActive: Bool) {
            self.id = id
            self.category = category
            self.label = label
            self.isActive = isActive
        }
    }

    public let id: UUID
    public let name: String
    public let groupIDs: Set<UUID>
    public let isDisabled: Bool
    public var isStarred: Bool
    public let subtitle: String
    public let providerCategory: ProviderCategory
    public let portDisplays: [Int]
    public let providerOptions: [ProviderOption]
    public let createdAt: Date
    public let searchKey: String

    public nonisolated init(
        id: UUID,
        name: String,
        groupIDs: Set<UUID> = [],
        isDisabled: Bool = false,
        isStarred: Bool = false,
        subtitle: String = "",
        providerCategory: ProviderCategory = .shell,
        portDisplays: [Int] = [],
        providerOptions: [ProviderOption] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.groupIDs = groupIDs
        self.isDisabled = isDisabled
        self.isStarred = isStarred
        self.subtitle = subtitle
        self.providerCategory = providerCategory
        self.portDisplays = portDisplays
        self.providerOptions = providerOptions
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
