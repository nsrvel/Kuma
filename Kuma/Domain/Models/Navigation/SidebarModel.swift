import SwiftUI
import CryptoKit

// MARK: - SidebarIcon

public enum SidebarIcon: Hashable, Sendable {
    case system(String)
    case asset(String)
}

// MARK: - SidebarAction

public struct SidebarAction: Identifiable, Sendable {
    public let id: UUID
    public let icon: String        // SF Symbol name
    public let tooltip: String
    public let handler: @Sendable () -> Void

    public init(id: UUID = UUID(), icon: String, tooltip: String, handler: @escaping @Sendable () -> Void) {
        self.id = id
        self.icon = icon
        self.tooltip = tooltip
        self.handler = handler
    }
}

extension SidebarAction: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: SidebarAction, rhs: SidebarAction) -> Bool { lhs.id == rhs.id }
}

// MARK: - SidebarNode

public struct SidebarNode: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var icon: SidebarIcon
    public var children: [SidebarEntry]?
    public var actions: [SidebarAction]
    public var badge: Int?
    public var isWorkspace: Bool
    public var isSpecialHeader: Bool
    public var isExpandedByDefault: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        icon: SidebarIcon,
        children: [SidebarEntry]? = nil,
        actions: [SidebarAction] = [],
        badge: Int? = nil,
        isWorkspace: Bool = false,
        isSpecialHeader: Bool = false,
        isExpandedByDefault: Bool = true
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.children = children
        self.actions = actions
        self.badge = badge
        self.isWorkspace = isWorkspace
        self.isSpecialHeader = isSpecialHeader
        self.isExpandedByDefault = isExpandedByDefault
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: SidebarNode, rhs: SidebarNode) -> Bool { lhs.id == rhs.id }
}

// MARK: - SidebarEntry

public enum SidebarEntry: Identifiable, Hashable, Sendable {
    case item(SidebarNode)
    case divider(id: UUID = UUID())

    public var id: UUID {
        switch self {
        case .item(let node):
            return node.id
        case .divider(let id):
            return id
        }
    }
}

// MARK: - UUID Deterministic Generator

extension UUID {
    public static func stable(_ string: String) -> UUID {
        let digest = SHA256.hash(data: Data(string.utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
