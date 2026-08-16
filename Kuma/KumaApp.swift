import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct KumaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator()
    @State private var workspaceStore = WorkspaceStore()

    init() {
        // Enforce single running process guard on launch
        if SingleInstanceGuard.activateExistingInstanceIfRunning() {
            exit(0)
        }
    }

    var body: some Scene {
        // ─── Scene 1: Main Workspace Window ───────────────────────────
        // Default root window scene opened by macOS
        WindowGroup(id: "main-workspace") {
            ContentView()
                .environment(coordinator)
                .environment(workspaceStore)
                .containerBackground(.thickMaterial, for: .window)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .commands {
            // 0. App Settings Menu & Shortcut (⌘,)
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .kumaOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

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

            // 2. Help Menu — re-show the onboarding guide
            CommandGroup(replacing: .help) {
                Button("Kuma Onboarding Guide") {
                    coordinator.resetToOnboarding()
                    NotificationCenter.default.post(name: .kumaOpenOnboarding, object: nil)
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
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
    }
}

// MARK: - Notification Names

extension NSNotification.Name {
    static let kumaOpenSettings = NSNotification.Name("kuma.openSettings")
    static let kumaOpenOnboarding = NSNotification.Name("kuma.openOnboarding")
}
