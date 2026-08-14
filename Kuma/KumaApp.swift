//
//  KumaApp.swift
//  Kuma
//
//  Created by Putra Rama on 14/08/26.
//

import SwiftUI

@main
struct KumaApp: App {
    @AppStorage("kuma.has_completed_onboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        // 1. Dedicated Onboarding Window (Opens on first launch)
        Window("Kuma Onboarding", id: "onboarding") {
            OnboardingWindowContainerView()
                .gesture(WindowDragGesture())
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .windowBackgroundDragBehavior(.enabled)

        // 2. Main Dashboard Window (Opens after onboarding or on subsequent launches)
        WindowGroup("Kuma", id: "main-workspace") {
            ContentView()
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Kuma Onboarding Guide") {
                    NSApp.sendAction(Selector(("openWindow:")), to: nil, from: "onboarding")
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
        }
    }
}
