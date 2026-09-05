import SwiftUI

public struct SettingsDangerZoneSection: View {
    @Binding var showResetConfirmation: Bool
    var isProcessing: Bool
    var onReset: () -> Void

    public init(
        showResetConfirmation: Binding<Bool>,
        isProcessing: Bool,
        onReset: @escaping () -> Void
    ) {
        self._showResetConfirmation = showResetConfirmation
        self.isProcessing = isProcessing
        self.onReset = onReset
    }

    public var body: some View {
        KumaFormSection(
            icon: "exclamationmark.triangle.fill",
            title: "Danger Zone",
            style: .danger
        ) {
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
