import SwiftUI

public struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    @Bindable var workspaceStore: WorkspaceStore

    public init(viewModel: SidebarViewModel, workspaceStore: WorkspaceStore) {
        self.viewModel = viewModel
        self.workspaceStore = workspaceStore
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Navigation List (Pure Apple HIG Native Inset Layout)
            List {
                // 1. Workspace Header Row + New Service Button + Divider
                VStack(spacing: 0) {
                    SidebarWorkspaceRow(store: workspaceStore)

                    SidebarNewServiceButton()

                    KumaDivider(opacity: 0.08, verticalPadding: 6, horizontalPadding: 8)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // 2. Main Navigation Items
                ForEach(viewModel.flattenedRows) { item in
                    VStack(spacing: 0) {
                        cellView(for: item)

                        if item.hasDividerAfter {
                            KumaDivider(opacity: 0.08, verticalPadding: 6, horizontalPadding: 8)
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
                withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                    viewModel.handleMove(direction)
                }
            }

            // Sidebar Sticky Footer (Settings & Help)
            sidebarFooter
        }
        .navigationSplitViewColumnWidth(
            min: KumaTheme.Sidebar.widthMin,
            ideal: KumaTheme.Sidebar.widthIdeal,
            max: KumaTheme.Sidebar.widthMax
        )
    }

    @ViewBuilder
    private func cellView(for item: SidebarViewModel.FlattenedRow) -> some View {
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
                    isSelected: viewModel.selectedID == node.id,
                    isExpanded: viewModel.isExpanded(node.id),
                    indentLevel: item.indentLevel,
                    onSelect: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                            viewModel.selectedID = node.id
                        }
                    },
                    onToggleExpand: {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                            viewModel.toggleExpanded(node.id)
                        }
                    }
                )
            }

        case .divider:
            EmptyView()
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            KumaDivider(opacity: 0.08, verticalPadding: 0, horizontalPadding: 8)

            HStack(spacing: 8) {
                SidebarFooterButton(icon: "gear", tooltip: "Settings (⌘,)") {
                    viewModel.selectedID = .stable("settings")
                }

                SidebarFooterButton(icon: "questionmark.circle", tooltip: "Help") {
                    if let url = URL(string: "https://www.linkedin.com/in/putra-rama-setiawan/") {
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
}

#Preview {
    SidebarView(
        viewModel: SidebarViewModel.makeDefault(),
        workspaceStore: WorkspaceStore()
    )
    .frame(width: 220, height: 600)
}
