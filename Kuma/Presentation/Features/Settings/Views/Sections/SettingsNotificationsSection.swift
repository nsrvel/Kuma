import SwiftUI
import UserNotifications

public struct SettingsNotificationsSection: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showPermissionAlert = false

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        KumaFormSection(
            icon: "bell.fill",
            title: "Notifications"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                KumaToggleField(
                    label: "Notify on Service Failure",
                    value: $viewModel.notifyOnCrash,
                    description: "Notify when a service fails or exits unexpectedly."
                )
                .onChange(of: viewModel.notifyOnCrash) { _, newValue in
                    handleNotifyOnCrashToggle(newValue: newValue)
                }
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
            let shouldPrompt = await viewModel.requestNotificationAuthorization()
            if shouldPrompt {
                showPermissionAlert = true
            }
        }
    }
}
