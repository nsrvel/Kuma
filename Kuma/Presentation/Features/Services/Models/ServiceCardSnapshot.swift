import Foundation

/// Presentation DTO for deck cards and table rows (mapped from `ServiceDeckItem`).
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

    public func toggling(starred: Bool) -> Self {
        var copy = self
        copy.isStarred = starred
        return copy
    }
}

extension ServiceCardSnapshot {
    public nonisolated init(deckItem: ServiceDeckItem) {
        let subtitle: String = {
            let target = deckItem.resolvedTarget.trimmingCharacters(in: .whitespacesAndNewlines)
            if !target.isEmpty { return target }
            if let desc = deckItem.serviceDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                return desc
            }
            return ""
        }()

        let options = deckItem.providerOptions.map { opt in
            let trimmed = opt.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = trimmed.isEmpty ? opt.category.sidebarLabel : trimmed
            return ProviderOption(
                id: opt.id,
                category: opt.category,
                label: label,
                isActive: opt.isActive
            )
        }

        self.init(
            id: deckItem.id,
            name: deckItem.name,
            groupIDs: deckItem.groupIDs,
            isDisabled: deckItem.isDisabled,
            isStarred: deckItem.isStarred,
            subtitle: subtitle,
            providerCategory: deckItem.activeProviderCategory,
            portDisplays: deckItem.localPorts,
            providerOptions: options,
            createdAt: deckItem.createdAt
        )
    }
}

extension Array where Element == ServiceDeckItem {
    public var asCardSnapshots: [ServiceCardSnapshot] {
        map { ServiceCardSnapshot(deckItem: $0) }
    }
}
