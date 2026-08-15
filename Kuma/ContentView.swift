//
//  ContentView.swift
//  Kuma
//
//  Created by Putra Rama on 14/08/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(WorkspaceStore.self) private var workspaceStore
    @State private var sidebarStore = SidebarStore.makeDefault()
    @Environment(\.openWindow) private var openWindow

    @State private var settingsStore = SettingsStore()

    var body: some View {
        NavigationSplitView {
            SidebarView(store: sidebarStore, workspaceStore: workspaceStore)
        } detail: {
            detailView(for: sidebarStore.selectedID)
        }
        .containerBackground(.thickMaterial, for: .window)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .frame(minWidth: KumaTheme.Window.minWidth, minHeight: KumaTheme.Window.minHeight)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("kuma.openSettings"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                sidebarStore.selectedID = .stable("settings")
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
            SettingsView(store: settingsStore, workspaceStore: workspaceStore)
        } else if let activeWorkspace = workspaceStore.activeWorkspace {
            // Main Dashboard Workspace Stage with Deck View & Inspector
            ServicesDeckView(workspaceID: activeWorkspace.id)
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
