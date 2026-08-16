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

    public init(
        entries: [SidebarEntry] = [],
        selectedID: UUID? = nil,
        expandedIDs: Set<UUID> = []
    ) {
        self.entries = entries.isEmpty ? Self.defaultEntries : entries
        self.selectedID = selectedID ?? .stable("all-services")
        self.expandedIDs = expandedIDs
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

    // MARK: - Default Entries

    public static var defaultEntries: [SidebarEntry] {
        [
            .item(SidebarNode(
                id: .stable("all-services"),
                title: "All Services",
                icon: .system("square.grid.2x2.fill"),
                children: nil,
                actions: [
                    SidebarAction(icon: "plus", tooltip: "New Service") {
                        NotificationCenter.default.post(name: NSNotification.Name("kumaCreateServiceRequested"), object: nil)
                    }
                ]
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
