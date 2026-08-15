import SwiftUI
import UserNotifications

public struct SettingsNotificationsSection: View {
    @Bindable var store: SettingsStore
    @State private var showPermissionAlert = false

    public init(store: SettingsStore) {
        self.store = store
    }

    public var body: some View {
        KumaFormSection(
            icon: "bell.fill",
            title: "Notifications"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                KumaToggleField(
                    label: "Notify on Service Failure",
                    value: $store.notifyOnCrash,
                    description: "Send a macOS system notification when a service crashes or exits unexpectedly."
                )
                .onChange(of: store.notifyOnCrash) { _, newValue in
                    handleNotifyOnCrashToggle(newValue: newValue)
                }

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Notify on Health Check Failure",
                    value: $store.notifyOnHealthFailure,
                    description: "Send alerts when a monitored endpoint or socket stops responding."
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Port Collision Safety Alerts",
                    value: $store.warnOnPortCollision,
                    description: "Alert before starting a service if the target local port is already bound."
                )
            }
        }
        .alert("Notification Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Kuma needs permission to send notifications. Please allow it in macOS System Settings.")
        }
    }

    private func handleNotifyOnCrashToggle(newValue: Bool) {
        guard newValue else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .notDetermined:
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                    await MainActor.run {
                        store.notifyOnCrash = granted
                        if !granted {
                            showPermissionAlert = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        store.notifyOnCrash = false
                    }
                }
            case .denied:
                await MainActor.run {
                    store.notifyOnCrash = false
                    showPermissionAlert = true
                }
            case .authorized, .provisional, .ephemeral:
                await MainActor.run {
                    store.notifyOnCrash = true
                }
            @unknown default:
                break
            }
        }
    }
}
