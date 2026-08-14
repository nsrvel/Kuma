//
//  ContentView.swift
//  Kuma
//
//  Created by Putra Rama on 14/08/26.
//

import SwiftUI

import SwiftUI

struct ContentView: View {
    @AppStorage("kuma.has_completed_onboarding") private var hasCompletedOnboarding: Bool = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            // Sidebar Workspace List
            List {
                Section("Workspaces") {
                    Label("Default", systemImage: "square.grid.2x2.fill")
                }

                Section("Providers") {
                    Label("Kubernetes", systemImage: "hexagon.fill")
                    Label("Docker", systemImage: "shippingbox.fill")
                    Label("Podman", systemImage: "cube.transparent.fill")
                    Label("Tunnels", systemImage: "bolt.horizontal.fill")
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
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
    }
}

#Preview {
    ContentView()
}
