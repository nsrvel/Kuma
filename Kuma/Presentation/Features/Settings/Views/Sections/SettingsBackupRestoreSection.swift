import SwiftUI

public struct SettingsBackupRestoreSection: View {
    var isProcessing: Bool
    var onExport: () -> Void
    var onImport: () -> Void

    public init(
        isProcessing: Bool,
        onExport: @escaping () -> Void,
        onImport: @escaping () -> Void
    ) {
        self.isProcessing = isProcessing
        self.onExport = onExport
        self.onImport = onImport
    }

    public var body: some View {
        KumaFormSection(
            icon: "internaldrive.fill",
            title: "Backup & Restore"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Backup")
                            .font(KumaFont.body)
                        Text("Export workspaces, services, and configuration to JSON.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Export") {
                        onExport()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                }

                Divider().opacity(0.3)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Backup")
                            .font(KumaFont.body)
                        Text("Restore workspaces and configuration from a JSON backup.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Import") {
                        onImport()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                }
            }
        }
    }
}
