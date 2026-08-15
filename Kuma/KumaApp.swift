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
        WindowGroup(id: "main-workspace") {
            ContentView()
                .environment(coordinator)
                .environment(workspaceStore)
                .containerBackground(.thickMaterial, for: .window)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentMinSize)
        .commands {
            // 0. App Settings Menu & Shortcut (⌘,)
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: NSNotification.Name("kuma.openSettings"), object: nil)
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
