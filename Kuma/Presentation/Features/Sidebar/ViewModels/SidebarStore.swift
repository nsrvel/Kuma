import SwiftUI
import Observation
import os

@MainActor
@Observable
public final class SidebarStore {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "SidebarStore")

    public private(set) var entries: [SidebarEntry]
    public var selectedID: UUID?
    public var expandedIDs: Set<UUID>

    /// Cached snapshot to avoid redundant rebuilds. Nil means "never built yet".
    private var lastProviderCounts: [ProviderCategory: Int]? = nil

    public init(
        entries: [SidebarEntry] = [],
        selectedID: UUID? = nil,
        expandedIDs: Set<UUID> = []
    ) {
        self.entries = entries
        self.selectedID = selectedID
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

    // MARK: - Dynamic Provider Rebuild

    /// Call this whenever the service list changes for the active workspace.
    /// Only rebuilds entries when the effective provider counts actually changed. O(n) where n = number of ProviderCategory cases (constant 8).
    public func updateProviderCounts(_ counts: [ProviderCategory: Int]) {
        guard counts != lastProviderCounts else { return }
        lastProviderCounts = counts
        rebuildEntries(from: counts)
    }

    private func rebuildEntries(from counts: [ProviderCategory: Int]) {
        let totalServices = counts.values.reduce(0, +)

        var result: [SidebarEntry] = [
            // "All Services" is ALWAYS present
            .item(SidebarNode(
                id: .stable("all-services"),
                title: "All Services",
                icon: .system("square.grid.2x2.fill"),
                children: nil,
                actions: [
                    SidebarAction(icon: "plus", tooltip: "New Service") {
                        // TODO: Trigger add service sheet
                    }
                ],
                badge: totalServices > 0 ? totalServices : nil
            ))
        ]

        // Collect active providers (services > 0), preserving ProviderCategory.allCases order
        let activeProviders = ProviderCategory.allCases.filter { (counts[$0] ?? 0) > 0 }

        if !activeProviders.isEmpty {
            result.append(.divider())

            for provider in activeProviders {
                let count = counts[provider] ?? 0
                result.append(.item(SidebarNode(
                    id: provider.stableID,
                    title: provider.sidebarLabel,
                    icon: .system(provider.icon),
                    children: nil,
                    actions: [
                        SidebarAction(icon: "plus", tooltip: provider.addTooltip) {}
                    ],
                    badge: count
                )))
            }
        }

        entries = result

        // If the currently selected provider row just disappeared, fall back to All Services
        if let selected = selectedID,
           !entries.contains(where: { $0.id == selected }) {
            selectedID = .stable("all-services")
        }

        Self.logger.debug("Sidebar rebuilt: \(activeProviders.count) active providers, \(totalServices) total services")
    }
}

// MARK: - Factory

extension SidebarStore {
    /// Creates a fresh sidebar for a new workspace — only "All Services" visible.
    /// Provider rows will appear automatically once services are created via `updateProviderCounts(_:)`.
    public static func makeDefault() -> SidebarStore {
        let store = SidebarStore(
            selectedID: .stable("all-services"),
            expandedIDs: []
        )
        store.updateProviderCounts([:])
        return store
    }
}
