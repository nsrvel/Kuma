import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(WorkspaceStore.self) private var workspaceStore
    @State private var sidebarViewModel = SidebarViewModel.makeDefault()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var settingsViewModel = SettingsViewModel()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(viewModel: sidebarViewModel, workspaceStore: workspaceStore)
        } detail: {
            detailView(for: sidebarViewModel.selectedID)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .onReceive(NotificationCenter.default.publisher(for: .kumaOpenSettings)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                sidebarViewModel.selectedID = .stable("settings")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kumaOpenOnboarding)) { _ in
            openWindow(id: "onboarding")
            dismissWindow(id: "main-workspace")
        }
        .task {
            if coordinator.currentPhase == .onboarding {
                openWindow(id: "onboarding")
                dismissWindow(id: "main-workspace")
            }
        }
        .sheet(isPresented: Bindable(workspaceStore).showCreateSheet) {
            WorkspaceFormSheet(store: workspaceStore, mode: .create, isPresented: Bindable(workspaceStore).showCreateSheet)
        }
        .sheet(item: Bindable(workspaceStore).workspaceToEdit) { ws in
            WorkspaceFormSheet(store: workspaceStore, mode: .edit(ws), isPresented: Binding(
                get: { workspaceStore.workspaceToEdit != nil },
                set: { if !$0 { workspaceStore.workspaceToEdit = nil } }
            ))
        }
        .withKumaAlerts()
    }

    @ViewBuilder
    private func detailView(for selectedID: UUID?) -> some View {
        if selectedID == .stable("settings") {
            SettingsView(viewModel: settingsViewModel, workspaceStore: workspaceStore)
        } else if selectedID == .stable("port-registry") {
            KumaEmptyStateView(
                iconName: "point.3.filled.connected.trianglepath.dotted",
                title: "Port Registry",
                description: "Monitor active localhost ports and detect port conflicts across your system."
            )
            .navigationTitle("Port Registry")
        } else if selectedID == .stable("live-logs") {
            KumaEmptyStateView(
                iconName: "terminal",
                title: "Live Logs",
                description: "Real-time aggregated stream of all stdout/stderr logs from running services."
            )
            .navigationTitle("Live Logs")
        } else if let activeWorkspace = workspaceStore.activeWorkspace {
            // Main Dashboard Workspace Stage with Deck View (All Services, Starred Filter, or Group Filter)
            let isStarred = (selectedID == .stable("starred-services"))
            let isStaticSection = (selectedID == .stable("all-services") || selectedID == .stable("starred-services") || selectedID == .stable("groups"))
            let targetGroupID: UUID? = isStaticSection ? nil : selectedID

            ServicesDeckView(
                workspaceID: activeWorkspace.id,
                isStarredOnly: isStarred,
                filterGroupID: targetGroupID
            )
            .id(activeWorkspace.id)
        } else {
            KumaEmptyStateView(
                iconName: "square.stack.3d.up.slash",
                title: "No Active Workspace",
                description: "Select or create a workspace from the sidebar to view your services."
            )
        }
    }
}

#Preview {
    ContentView()
}
