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
                        Text("Restore all preferences and binary paths to factory defaults without affecting your workspaces or services.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset Settings…") {
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
                        Text("Permanently delete all workspaces, services, providers, and port mappings.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset Data…") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isProcessing)
                }
            }
        }
        .confirmationDialog(
            "Reset Settings to Default?",
            isPresented: $showResetSettingsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) {
                onResetSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all preferences, appearance, and tool paths to their default values. Your configured workspaces, services, and credentials will not be deleted.")
        }
        .confirmationDialog(
            "Reset All Data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                onReset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your configured workspaces and services will be permanently deleted.")
        }
    }
}
