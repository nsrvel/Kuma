//
//  SidebarView.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% Pixel-Perfect Match with Kuma V3 SidebarView.
//

import SwiftUI

public struct SidebarView: View {
    @Bindable var store: SidebarStore
    @Bindable var workspaceStore: WorkspaceStore

    public init(store: SidebarStore, workspaceStore: WorkspaceStore) {
        self.store = store
        self.workspaceStore = workspaceStore
    }

    private struct FlattenedRow: Identifiable {
        let id: UUID
        let entry: SidebarEntry
        let indentLevel: Int
        let isPlaceholder: Bool
        let hasDividerAfter: Bool
    }

    private var flattenedRows: [FlattenedRow] {
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

            if case .item(let node) = entry, let children = node.children, store.isExpanded(node.id) {
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

        for (index, entry) in store.entries.enumerated() {
            if case .divider = entry {
                continue
            }

            let startCount = result.count
            appendEntry(entry, indentLevel: 0)

            let nextIndex = index + 1
            if nextIndex < store.entries.count, case .divider = store.entries[nextIndex] {
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

        return result
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Navigation List (Pure Apple HIG Native Inset Layout)
            List {
                // 1. Workspace Header Row + Divider (Single List Item for tight pixel-perfect gap)
                VStack(spacing: 0) {
                    SidebarWorkspaceRow(store: workspaceStore)
                        .padding(.top, 2)
                        .padding(.bottom, 4)

                    KumaDivider(opacity: 0.08, verticalPadding: 0, horizontalPadding: 4)
                        .padding(.top, 2)
                        .padding(.bottom, 2)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // 2. Main Navigation Items
                ForEach(flattenedRows) { item in
                    VStack(spacing: 0) {
                        cellView(for: item)

                        if item.hasDividerAfter {
                            KumaDivider(opacity: 0.08, verticalPadding: 4, horizontalPadding: 4)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .padding(.horizontal, -8)
            .focusable()
            .focusEffectDisabled()
            .onMoveCommand { direction in
                handleMove(direction)
            }

            // Sidebar Sticky Footer (Settings & Help)
            VStack(spacing: 0) {
                KumaDivider(opacity: 0.08, horizontalPadding: 8)

                HStack(spacing: 8) {
                    SidebarFooterButton(icon: "gear", tooltip: "Settings") {
                        store.selectedID = .stable("settings")
                    }

                    SidebarFooterButton(icon: "questionmark.circle", tooltip: "Help") {
                        if let url = URL(string: "https://github.com/lokastudio/kuma") {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.clear)
        }
        .navigationSplitViewColumnWidth(
            min: KumaTheme.Sidebar.widthMin,
            ideal: KumaTheme.Sidebar.widthIdeal,
            max: KumaTheme.Sidebar.widthMax
        )
    }

    @ViewBuilder
    private func cellView(for item: FlattenedRow) -> some View {
        switch item.entry {
        case .item(let node):
            if item.isPlaceholder {
                SidebarEmptyPlaceholderRow(
                    title: node.title,
                    indentLevel: item.indentLevel
                )
            } else {
                SidebarRowView(
                    node: node,
                    isSelected: store.selectedID == node.id,
                    isExpanded: store.isExpanded(node.id),
                    indentLevel: item.indentLevel,
                    onSelect: { store.selectedID = node.id },
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            store.toggleExpanded(node.id)
                        }
                    }
                )
            }

        case .divider:
            KumaDivider(opacity: 0.08, verticalPadding: 4)
                .padding(.leading, CGFloat(item.indentLevel) * KumaTheme.Sidebar.indentWidth + 8)
                .padding(.trailing, 8)
        }
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        let navigableRows = flattenedRows.filter { isNavigable($0) }
        guard !navigableRows.isEmpty else { return }

        let currentIndex = navigableRows.firstIndex(where: { $0.id == store.selectedID })

        switch direction {
        case .down:
            if let index = currentIndex {
                let nextIndex = index + 1
                if nextIndex < navigableRows.count {
                    store.selectedID = navigableRows[nextIndex].id
                }
            } else {
                store.selectedID = navigableRows.first?.id
            }
        case .up:
            if let index = currentIndex {
                let prevIndex = index - 1
                if prevIndex >= 0 {
                    store.selectedID = navigableRows[prevIndex].id
                }
            } else {
                store.selectedID = navigableRows.last?.id
            }
        case .left:
            if let selectedID = store.selectedID,
               let row = navigableRows.first(where: { $0.id == selectedID }),
               case .item(let node) = row.entry,
               node.children != nil,
               store.isExpanded(selectedID) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    _ = store.expandedIDs.remove(selectedID)
                }
            }
        case .right:
            if let selectedID = store.selectedID,
               let row = navigableRows.first(where: { $0.id == selectedID }),
               case .item(let node) = row.entry,
               node.children != nil,
               !store.isExpanded(selectedID) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    _ = store.expandedIDs.insert(selectedID)
                }
            }
        default:
            break
        }
    }

    private func isNavigable(_ item: FlattenedRow) -> Bool {
        switch item.entry {
        case .item:
            return !item.isPlaceholder
        case .divider:
            return false
        }
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
}
