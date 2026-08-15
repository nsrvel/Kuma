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

    var body: some View {
        NavigationSplitView {
            SidebarView(store: sidebarStore, workspaceStore: workspaceStore)
        } detail: {
            // Main Dashboard Workspace Stage
            VStack(spacing: KumaSpacing.lg) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)

                Text("Kuma Main Workspace")
                    .font(KumaFont.title)

                Text("Zero active services. Add your first service runner to get started.")
                    .font(KumaFont.body)
                    .foregroundStyle(.secondary)

                Button("Show Onboarding (Debug)") {
                    openWindow(id: "onboarding")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(.thickMaterial, for: .window)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .frame(minWidth: KumaTheme.Window.minWidth, minHeight: KumaTheme.Window.minHeight)
        .sheet(isPresented: Bindable(workspaceStore).showCreateSheet) {
            WorkspaceFormSheet(store: workspaceStore, mode: .create, isPresented: Bindable(workspaceStore).showCreateSheet)
        }
        .sheet(item: Bindable(workspaceStore).workspaceToEdit) { ws in
            WorkspaceFormSheet(store: workspaceStore, mode: .edit(ws), isPresented: Binding(
                get: { workspaceStore.workspaceToEdit != nil },
                set: { if !$0 { workspaceStore.workspaceToEdit = nil } }
            ))
        }
    }
}

#Preview {
    ContentView()
}
