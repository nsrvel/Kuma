import SwiftUI
import Observation
import os

@MainActor
@Observable
public final class SidebarViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "SidebarViewModel")

    public private(set) var entries: [SidebarEntry]
    public var selectedID: UUID?
    public var expandedIDs: Set<UUID>
    public var editingGroupID: UUID? = nil

    private let serviceRepository: any ServiceRepositoryProtocol

    public init(
        entries: [SidebarEntry] = [],
        selectedID: UUID? = nil,
        expandedIDs: Set<UUID> = [],
        serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()
    ) {
        self.serviceRepository = serviceRepository
        let finalEntries = entries.isEmpty ? Self.defaultEntries : entries
        self.entries = finalEntries
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
    }

    // MARK: - Group Sync & Management

    public func loadGroups(forWorkspace workspaceID: UUID) {
        Task {
            do {
                let groups = try await serviceRepository.fetchGroups(forWorkspace: workspaceID)
                self.syncGroupsToEntries(groups: groups, workspaceID: workspaceID)
            } catch {
                Self.logger.error("Failed to load groups: \(error.localizedDescription)")
            }
        }
    }

    private func syncGroupsToEntries(groups: [ServiceGroup], workspaceID: UUID) {
        let groupEntries = groups.map { g in
            SidebarEntry.item(
                SidebarNode(
                    id: g.id,
                    title: g.name,
                    icon: .system("folder.fill"),
                    children: nil
                )
            )
        }

        var newEntries: [SidebarEntry] = []
        for entry in self.entries {
            switch entry {
            case .item(var node):
                if node.id == .stable("groups") {
                    node.children = groupEntries
                    node.actions = [
                        SidebarAction(icon: "plus", tooltip: "New Group") { [weak self] in
                            Task { @MainActor [weak self] in
                                self?.createNewGroup(workspaceID: workspaceID)
                            }
                        }
                    ]
                    newEntries.append(.item(node))
                } else {
                    newEntries.append(entry)
                }
            case .divider:
                newEntries.append(entry)
            }
        }
        self.entries = newEntries
    }

    public func createNewGroup(workspaceID: UUID) {
        Task {
            do {
                let defaultName = "New Group"
                let newGroup = try await serviceRepository.createGroup(workspaceID: workspaceID, name: defaultName)
                self.loadGroups(forWorkspace: workspaceID)
                self.expandedIDs.insert(.stable("groups"))
                self.editingGroupID = newGroup.id
                self.selectedID = newGroup.id
            } catch {
                Self.logger.error("Failed to create group: \(error.localizedDescription)")
            }
        }
    }

    public func commitGroupName(id: UUID, newName: String, workspaceID: UUID) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Untitled Group" : trimmed
        self.editingGroupID = nil

        Task {
            do {
                try await serviceRepository.renameGroup(id: id, newName: finalName)
                self.loadGroups(forWorkspace: workspaceID)
            } catch {
                Self.logger.error("Failed to rename group: \(error.localizedDescription)")
            }
        }
    }

    public func deleteGroup(id: UUID, workspaceID: UUID) {
        if selectedID == id {
            selectedID = .stable("all-services")
        }
        Task {
            do {
                try await serviceRepository.deleteGroup(id: id)
                self.loadGroups(forWorkspace: workspaceID)
            } catch {
                Self.logger.error("Failed to delete group: \(error.localizedDescription)")
            }
        }
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
            .divider(),
            .item(SidebarNode(
                id: .stable("port-registry"),
                title: "Port Registry",
                icon: .system("arrow.left.arrow.right"),
                children: nil
            )),
            .item(SidebarNode(
                id: .stable("live-logs"),
                title: "Live Logs",
                icon: .system("terminal"),
                children: nil
            )),
            .divider(),
            .item(SidebarNode(
                id: .stable("groups"),
                title: "Groups",
                icon: .system("folder"),
                children: [],
                actions: [
                    SidebarAction(icon: "plus", tooltip: "New Group") {
                        NotificationCenter.default.post(name: NSNotification.Name("kumaCreateGroupRequested"), object: nil)
                    }
                ],
                isSpecialHeader: true,
                isExpandedByDefault: true
            ))
        ]
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
