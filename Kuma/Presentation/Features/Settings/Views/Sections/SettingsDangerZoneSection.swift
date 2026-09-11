import SwiftUI

public struct SettingsDangerZoneSection: View {
    @Binding var showResetConfirmation: Bool
    @Binding var showResetSettingsConfirmation: Bool
    var isProcessing: Bool
    var onReset: () -> Void
    var onResetSettings: () -> Void

    public init(
        showResetConfirmation: Binding<Bool>,
        showResetSettingsConfirmation: Binding<Bool>,
        isProcessing: Bool,
        onReset: @escaping () -> Void,
        onResetSettings: @escaping () -> Void
    ) {
        self._showResetConfirmation = showResetConfirmation
        self._showResetSettingsConfirmation = showResetSettingsConfirmation
        self.isProcessing = isProcessing
        self.onReset = onReset
        self.onResetSettings = onResetSettings
    }

    public var body: some View {
        KumaFormSection(
            icon: "exclamationmark.triangle.fill",
            title: "Danger Zone",
            style: .danger
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                // Row 1: Reset Settings to Default (Safe: keeps DB)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Settings to Default")
                            .font(KumaFont.body)
                            .foregroundStyle(.primary)
                        Text("Restore preferences without affecting workspaces.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset") {
                        showResetSettingsConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                }

                Divider().opacity(0.3)

                // Row 2: Reset All Data (Destructive: wipes DB + resets app)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset All Data")
                            .font(KumaFont.body)
                            .foregroundStyle(.red)
                        Text("Permanently delete all workspaces and services.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset All") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isProcessing)
                }
            }
        }
        .confirmationDialog(
            "Reset Settings?",
            isPresented: $showResetSettingsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Settings", role: .destructive) {
                onResetSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All preferences and tool paths will be reset to defaults. Workspaces and services will not be affected.")
        }
        .confirmationDialog(
            "Reset All Data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All Data", role: .destructive) {
                onReset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All workspaces, services, and data will be permanently deleted.")
        }
    }
}
