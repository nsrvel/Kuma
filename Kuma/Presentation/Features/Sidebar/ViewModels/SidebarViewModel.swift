import SwiftUI
import Observation
import os

@MainActor
@Observable
public final class SidebarViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "SidebarViewModel")

    public private(set) var entries: [SidebarEntry] = [] {
        didSet { rebuildFlattenedRows() }
    }
    public var selectedID: UUID?
    public var expandedIDs: Set<UUID> = [] {
        didSet { rebuildFlattenedRows() }
    }
    public private(set) var flattenedRows: [FlattenedRow] = []
    public var groups: [ServiceGroup] = []
    public var editingGroupID: UUID? = nil

    private let groupRepository: any ServiceGroupRepositoryProtocol
    private var currentWorkspaceID: UUID? = nil

    public init(
        entries: [SidebarEntry] = [],
        selectedID: UUID? = nil,
        expandedIDs: Set<UUID> = [],
        groupRepository: any ServiceGroupRepositoryProtocol = ServiceGroupRepository()
    ) {
        self.groupRepository = groupRepository
        let finalEntries = entries.isEmpty ? Self.defaultEntries : entries
        self.selectedID = selectedID ?? .stable("all-services")

        var initialExpanded = expandedIDs
        if expandedIDs.isEmpty {
            for entry in finalEntries {
                if case .item(let node) = entry, node.isExpandedByDefault {
                    initialExpanded.insert(node.id)
                }
            }
        }
        self.expandedIDs = initialExpanded
        self.entries = finalEntries
        self.rebuildFlattenedRows()
    }

    // MARK: - Expand / Collapse

    public func toggleExpanded(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    public func isExpanded(_ id: UUID) -> Bool {
        expandedIDs.contains(id)
    }

    // MARK: - Groups Data Management

    public func loadGroups(workspaceID: UUID) async {
        self.currentWorkspaceID = workspaceID
        do {
            self.groups = try await groupRepository.fetchAll(workspaceID: workspaceID)
            rebuildEntries()
        } catch {
            Self.logger.error("Failed to load groups for workspace \(workspaceID): \(error)")
        }
    }

    public func addGroup(name: String = "New Group", workspaceID: UUID) {
        self.currentWorkspaceID = workspaceID
        let nextSortOrder = (groups.map(\.sortOrder).max() ?? 0) + 1
        let newGroup = ServiceGroup(
            name: name,
            workspaceID: workspaceID,
            sortOrder: nextSortOrder
        )

        // 1. Instant Optimistic In-Memory Update (0ms)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            self.groups.append(newGroup)
            self.expandedIDs.insert(.stable("groups"))
            self.editingGroupID = newGroup.id
            self.selectedID = newGroup.id
            self.rebuildEntries()
        }

        // 2. Background Persistence
        Task {
            do {
                try await groupRepository.insert(newGroup)
                NotificationCenter.default.post(name: .kumaGroupsUpdated, object: newGroup.id)
            } catch {
                Self.logger.error("Failed to insert group: \(error)")
            }
        }
    }

    public func renameGroup(id: UUID, newName: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Untitled Group" : trimmed

        // 1. Instant Optimistic In-Memory Update (0ms)
        var updated = groups[index]
        updated.name = finalName
        updated.updatedAt = Date()

        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
            self.groups[index] = updated
            self.editingGroupID = nil
            self.rebuildEntries()
        }

        // 2. Background Persistence
        Task {
            do {
                try await groupRepository.update(updated)
                NotificationCenter.default.post(name: .kumaGroupsUpdated, object: id)
            } catch {
                Self.logger.error("Failed to rename group \(id): \(error)")
            }
        }
    }

    public func deleteGroup(id: UUID) {
        // 1. Instant Optimistic In-Memory Update (0ms)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            self.groups.removeAll(where: { $0.id == id })
            if self.selectedID == id {
                self.selectedID = .stable("all-services")
            }
            if self.editingGroupID == id {
                self.editingGroupID = nil
            }
            self.rebuildEntries()
        }

        // 2. Background Persistence
        Task {
            do {
                try await groupRepository.delete(id: id)
                NotificationCenter.default.post(name: .kumaGroupsUpdated, object: id)
            } catch {
                Self.logger.error("Failed to delete group \(id): \(error)")
            }
        }
    }

    public func groupIDForSelectedRow(_ id: UUID?) -> UUID? {
        guard let id else { return nil }
        return groups.first(where: { $0.id == id })?.id
    }

    // MARK: - Reordering

    public func moveGroups(fromOffsets source: IndexSet, toOffset destination: Int) {
        // 1. Instant Optimistic In-Memory Update (0ms)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            self.groups.move(fromOffsets: source, toOffset: destination)
            for (index, _) in self.groups.enumerated() {
                self.groups[index].sortOrder = index
                self.groups[index].updatedAt = Date()
            }
            self.rebuildEntries()
        }

        // 2. Background Persistence
        let orders = self.groups.enumerated().map { (index, group) in
            (id: group.id, sortOrder: index)
        }
        Task {
            do {
                try await groupRepository.updateSortOrders(orders)
                NotificationCenter.default.post(name: .kumaGroupsUpdated, object: nil)
            } catch {
                Self.logger.error("Failed to persist group reorder: \(error)")
            }
        }
    }

    public func moveGroupUp(id: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == id }), index > 0 else { return }
        moveGroups(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
    }

    public func moveGroupDown(id: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == id }), index < groups.count - 1 else { return }
        moveGroups(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
    }

    public func canMoveGroupUp(id: UUID) -> Bool {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        return index > 0
    }

    public func canMoveGroupDown(id: UUID) -> Bool {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        return index < groups.count - 1
    }

    public func reorderGroup(draggedID: UUID, targetID: UUID) {
        guard draggedID != targetID,
              let fromIndex = groups.firstIndex(where: { $0.id == draggedID }),
              let toIndex = groups.firstIndex(where: { $0.id == targetID }) else { return }

        let destination = toIndex > fromIndex ? toIndex + 1 : toIndex
        moveGroups(fromOffsets: IndexSet(integer: fromIndex), toOffset: destination)
    }

    public var fixedRows: [FlattenedRow] {
        flattenedRows.filter { row in
            guard case .item(let node) = row.entry else { return true }
            return node.id != .stable("groups") && !node.isGroupRow && !row.isPlaceholder
        }
    }

    public var groupsHeaderRow: FlattenedRow? {
        flattenedRows.first { $0.id == .stable("groups") }
    }

    private func rebuildEntries() {
        let groupChildren: [SidebarEntry] = groups.map { group in
            .item(SidebarNode(
                id: group.id,
                title: group.name,
                icon: .system("folder"),
                children: nil,
                isGroupRow: true
            ))
        }

        let groupsHeader = SidebarNode(
            id: .stable("groups"),
            title: "Groups",
            icon: .system("folder"),
            children: groupChildren,
            actions: [
                SidebarAction(icon: "plus", tooltip: "New Group") { [weak self] in
                    guard let self, let wsID = self.currentWorkspaceID else { return }
                    self.addGroup(workspaceID: wsID)
                }
            ],
            isSpecialHeader: true,
            isExpandedByDefault: true
        )

        self.entries = [
            .item(SidebarNode(
                id: .stable("all-services"),
                title: "All Services",
                icon: .system("square.grid.2x2.fill"),
                children: nil
            )),
            .item(SidebarNode(
                id: .stable("starred-services"),
                title: "Starred",
                icon: .system("star"),
                children: nil
            )),
            .item(SidebarNode(
                id: .stable("live-logs"),
                title: "Live Logs",
                icon: .system("terminal"),
                children: nil
            )),
            .item(groupsHeader)
        ]
    }

    public static var defaultEntries: [SidebarEntry] {
        [
            .item(SidebarNode(
                id: .stable("all-services"),
                title: "All Services",
                icon: .system("square.grid.2x2.fill"),
                children: nil
            )),
            .item(SidebarNode(
                id: .stable("starred-services"),
                title: "Starred",
                icon: .system("star"),
                children: nil
            )),
            .item(SidebarNode(
                id: .stable("live-logs"),
                title: "Live Logs",
                icon: .system("terminal"),
                children: nil
            )),
            .item(SidebarNode(
                id: .stable("groups"),
                title: "Groups",
                icon: .system("folder"),
                children: [],
                actions: [
                    SidebarAction(icon: "plus", tooltip: "New Group") {
                        // Action handled dynamically when VM is initialized
                    }
                ],
                isSpecialHeader: true,
                isExpandedByDefault: true
            ))
        ]
    }

    // MARK: - Flattened Hierarchy for Native List

    public struct FlattenedRow: Identifiable, Equatable {
        public let id: UUID
        public let entry: SidebarEntry
        public let indentLevel: Int
        public let isPlaceholder: Bool
        public let hasDividerAfter: Bool

        public var isNavigable: Bool {
            switch entry {
            case .item: return !isPlaceholder
            case .divider: return false
            }
        }
    }

    private func rebuildFlattenedRows() {
        var result: [FlattenedRow] = []

        func appendEntry(_ entry: SidebarEntry, indentLevel: Int) {
            if case .divider = entry {
                result.append(
                    FlattenedRow(
                        id: entry.id,
                        entry: entry,
                        indentLevel: indentLevel,
                        isPlaceholder: false,
                        hasDividerAfter: false
                    )
                )
                return
            }

            result.append(
                FlattenedRow(
                    id: entry.id,
                    entry: entry,
                    indentLevel: indentLevel,
                    isPlaceholder: false,
                    hasDividerAfter: false
                )
            )

            if case .item(let node) = entry, let children = node.children, isExpanded(node.id) {
                if children.isEmpty {
                    let placeholderId = UUID.stable(node.id.uuidString + ".empty-placeholder")
                    let placeholderNode = SidebarNode(
                        id: placeholderId,
                        title: emptyPlaceholderText(for: node),
                        icon: .system("")
                    )
                    result.append(
                        FlattenedRow(
                            id: placeholderId,
                            entry: .item(placeholderNode),
                            indentLevel: indentLevel + 1,
                            isPlaceholder: true,
                            hasDividerAfter: false
                        )
                    )
                } else {
                    for child in children {
                        appendEntry(child, indentLevel: indentLevel + 1)
                    }
                }
            }
        }

        for (index, entry) in entries.enumerated() {
            if case .divider = entry {
                continue
            }

            let startCount = result.count
            appendEntry(entry, indentLevel: 0)

            let nextIndex = index + 1
            if nextIndex < entries.count, case .divider = entries[nextIndex] {
                if result.count > startCount, let lastIndex = result.indices.last {
                    result[lastIndex] = FlattenedRow(
                        id: result[lastIndex].id,
                        entry: result[lastIndex].entry,
                        indentLevel: result[lastIndex].indentLevel,
                        isPlaceholder: result[lastIndex].isPlaceholder,
                        hasDividerAfter: true
                    )
                }
            }
        }

        self.flattenedRows = result
    }

    private func emptyPlaceholderText(for node: SidebarNode) -> String {
        if node.title == "Starred" {
            return "No starred items"
        } else if node.title == "All Services" {
            return "No services"
        } else {
            return "No \(node.title.lowercased()) services"
        }
    }

    public func handleMove(_ direction: MoveCommandDirection) {
        let navigableRows = flattenedRows.filter { $0.isNavigable }
        guard !navigableRows.isEmpty else { return }

        let currentIndex = navigableRows.firstIndex(where: { $0.id == selectedID })

        switch direction {
        case .down:
            if let index = currentIndex {
                let nextIndex = index + 1
                if nextIndex < navigableRows.count {
                    selectedID = navigableRows[nextIndex].id
                }
            } else {
                selectedID = navigableRows.first?.id
            }
        case .up:
            if let index = currentIndex {
                let prevIndex = index - 1
                if prevIndex >= 0 {
                    selectedID = navigableRows[prevIndex].id
                }
            } else {
                selectedID = navigableRows.last?.id
            }
        case .left:
            if let selectedID,
               let row = navigableRows.first(where: { $0.id == selectedID }),
               case .item(let node) = row.entry,
               node.children != nil,
               isExpanded(selectedID) {
                _ = expandedIDs.remove(selectedID)
            }
        case .right:
            if let selectedID,
               let row = navigableRows.first(where: { $0.id == selectedID }),
               case .item(let node) = row.entry,
               node.children != nil,
               !isExpanded(selectedID) {
                _ = expandedIDs.insert(selectedID)
            }
        default:
            break
        }
    }
}

// MARK: - Factory

extension SidebarViewModel {
    public static func makeDefault() -> SidebarViewModel {
        SidebarViewModel(
            selectedID: .stable("all-services"),
            expandedIDs: []
        )
    }
}
