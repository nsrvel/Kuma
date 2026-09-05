import SwiftUI

@main
struct KumaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator()
    @State private var workspaceStore = WorkspaceStore()

    var body: some Scene {
        // ─── Scene 1: Main Workspace Window ───────────────────────────
        // Default root window scene opened by macOS
        WindowGroup(id: "main-workspace") {
            ContentView()
                .environment(coordinator)
                .environment(workspaceStore)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .commands {
            KumaCommands(coordinator: coordinator, workspaceStore: workspaceStore)
        }

        // ─── Scene 2: Onboarding Wizard Window ─────────────────────────
        // Compact plain utility window, floating, suppressed by default
        Window("Welcome to Kuma", id: "onboarding") {
            OnboardingWizardView {
                coordinator.transitionTo(.mainWorkspace)
            }
            .environment(coordinator)
            .gesture(WindowDragGesture())
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        // ─── Scene 3: macOS MenuBar Extra ────────────────────────────
        // Compact Status Item in macOS Menu Bar with quick service controls
        MenuBarExtra("Kuma", systemImage: "bolt.horizontal.fill") {
            MenuBarPopupView()
                .environment(coordinator)
                .environment(workspaceStore)
        }
        .menuBarExtraStyle(.window)
    }
}


