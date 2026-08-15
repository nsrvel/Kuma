//
//  KumaApp.swift
//  Kuma
//
//  Created by Putra Rama on 14/08/26.
//

import SwiftUI

@main
struct KumaApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var workspaceStore = WorkspaceStore()

    init() {
        // Enforce single running process guard on launch
        if SingleInstanceGuard.activateExistingInstanceIfRunning() {
            exit(0)
        }
    }

    var body: some Scene {
        // 1. Dedicated Onboarding Window (Opens on first launch)
        Window("Kuma Onboarding", id: "onboarding") {
            OnboardingWindowContainerView()
                .environment(coordinator)
                .gesture(WindowDragGesture())
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .windowBackgroundDragBehavior(.enabled)

        // 2. Main Dashboard Window (Opens after onboarding or on subsequent launches)
        WindowGroup("Kuma", id: "main-workspace") {
            ContentView()
                .environment(coordinator)
                .environment(workspaceStore)
        }
        .defaultSize(width: KumaTheme.Window.idealWidth, height: KumaTheme.Window.idealHeight)
        .windowResizability(.contentMinSize)
        .commands {
            // 1. Workspaces Menu & Global Keyboard Shortcuts (⌘1, ⌘2, ⌘3...)
            CommandMenu("Workspaces") {
                ForEach(Array(workspaceStore.workspaces.enumerated()), id: \.element.id) { index, ws in
                    if index < 9 {
                        Button(ws.name) {
                            workspaceStore.selectWorkspace(ws)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])
                    } else {
                        Button(ws.name) {
                            workspaceStore.selectWorkspace(ws)
                        }
                    }
                }

                Divider()

                Button("New Workspace…") {
                    workspaceStore.showCreateSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            // 2. Help Menu
            CommandGroup(replacing: .help) {
                Button("Kuma Onboarding Guide") {
                    coordinator.resetToOnboarding()
                    NSApp.sendAction(Selector(("openWindow:")), to: nil, from: "onboarding")
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
        }
    }
}
