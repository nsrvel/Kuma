import AppKit
import Foundation
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if SingleInstanceGuard.activateExistingInstanceIfRunning() {
            // Defer termination to next turn of runloop so AppKit lifecycle finishes cleanly
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return
        }

        UNUserNotificationCenter.current().delegate = self
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await ProcessRegistry.shared.terminateAll()
            await LogFileWriter.shared.flushAll()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
