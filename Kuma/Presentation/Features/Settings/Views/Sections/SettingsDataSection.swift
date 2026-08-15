//
//  SettingsDataSection.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect Data Backup, Restore & Danger Zone Section.
//

import SwiftUI
import UniformTypeIdentifiers

public struct SettingsDataSection: View {
    @Bindable var workspaceStore: WorkspaceStore

    @State private var showResetConfirmation = false
    @State private var alertMessage: String? = nil
    @State private var isProcessing = false

    public init(workspaceStore: WorkspaceStore) {
        self.workspaceStore = workspaceStore
    }

    public var body: some View {
        VStack(spacing: KumaSpacing.xl) {
            KumaFormSection(
                icon: "internaldrive.fill",
                title: "Data Backup & Restore"
            ) {
                VStack(alignment: .leading, spacing: KumaSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Configuration Backup")
                                .font(KumaFont.body)
                            Text("Export all workspaces, services, providers, and port mappings to a JSON file.")
                                .font(KumaFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Export…") {
                            exportData()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)
                    }

                    Divider().opacity(0.3)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Configuration Backup")
                                .font(KumaFont.body)
                            Text("Restore configuration data from a Kuma JSON backup file.")
                                .font(KumaFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Import…") {
                            importData()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)
                    }
                }
            }

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
        }
        .confirmationDialog(
            "Reset All Data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                resetData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your configured workspaces and services will be permanently deleted.")
        }
        .alert("Database Operation", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.title = "Export Kuma Backup"
        panel.nameFieldStringValue = "kuma-backup-\(formattedDate()).json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isProcessing = true
        Task {
            do {
                let backup = DataPortService.KumaBackup(
                    workspaces: workspaceStore.workspaces
                )
                let data = try DataPortService.encodeBackup(backup)
                try data.write(to: url)
                await MainActor.run {
                    isProcessing = false
                    alertMessage = "Backup successfully exported to \(url.lastPathComponent)."
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    alertMessage = "Failed to export data: \(error.localizedDescription)"
                }
            }
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.title = "Import Kuma Backup"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isProcessing = true
        Task {
            do {
                let data = try Data(contentsOf: url)
                let backup = try DataPortService.decodeBackup(from: data)
                await MainActor.run {
                    workspaceStore.restoreWorkspaces(backup.workspaces)
                    isProcessing = false
                    alertMessage = "Backup successfully imported (\(backup.workspaces.count) workspaces restored)!"
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    alertMessage = "Failed to import backup: \(error.localizedDescription)"
                }
            }
        }
    }

    private func resetData() {
        isProcessing = true
        Task {
            DataPortService.resetAllUserDefaults()
            await MainActor.run {
                isProcessing = false
                DataPortService.relaunchApp()
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
