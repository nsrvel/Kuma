import SwiftUI
import UniformTypeIdentifiers

public struct SettingsDataSection: View {
    @Bindable var workspaceStore: WorkspaceStore

    @State private var showResetConfirmation = false
    @State private var showImportPreview = false
    @State private var loadedBackup: DataPortService.KumaBackup? = nil
    @State private var pendingImportFileName: String = ""
    @State private var alertMessage: String? = nil
    @State private var isProcessing = false

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    public init(workspaceStore: WorkspaceStore) {
        self.workspaceStore = workspaceStore
    }

    public var body: some View {
        VStack(spacing: KumaSpacing.xl) {
            SettingsBackupRestoreSection(
                isProcessing: isProcessing,
                onExport: { exportData() },
                onImport: { promptImportFile() }
            )

            SettingsDangerZoneSection(
                showResetConfirmation: $showResetConfirmation,
                isProcessing: isProcessing,
                onReset: { resetData() }
            )
        }
        .sheet(item: $loadedBackup) { backup in
            ImportPreviewSheet(
                backup: backup,
                fileName: pendingImportFileName,
                existingWorkspaceIDs: Set(workspaceStore.workspaces.map(\.id)),
                onConfirmImport: { selectedWorkspaces, selectedServices in
                    loadedBackup = nil
                    executeSelectiveImport(
                        backup: backup,
                        selectedWorkspaces: selectedWorkspaces,
                        selectedServices: selectedServices
                    )
                }
            )
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
        SettingsDataPanelPresenter.presentSavePanel(
            title: "Export Kuma Backup",
            defaultFileName: "kuma-backup-\(DataPortService.backupDateString).json"
        ) { url in
            self.performExport(to: url)
        }
    }

    private func performExport(to url: URL) {
        isProcessing = true
        Task {
            do {
                let dataPort = DataPortRepository()
                let backup = try await dataPort.exportAll()
                let data = try DataPortService.encodeBackup(backup)
                try data.write(to: url, options: .atomic)
                isProcessing = false
                alertMessage = "Backup successfully exported to \(url.lastPathComponent)."
            } catch {
                isProcessing = false
                alertMessage = "Failed to export data: \(error.localizedDescription)"
            }
        }
    }

    private func promptImportFile() {
        SettingsDataPanelPresenter.presentOpenPanel(
            title: "Import Kuma Backup"
        ) { url in
            self.processImportUrl(url)
        }
    }

    private func processImportUrl(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let backup = try DataPortService.decodeBackup(from: data)
            self.loadedBackup = backup
            self.pendingImportFileName = url.lastPathComponent
            self.showImportPreview = true
        } catch {
            alertMessage = "Failed to read backup file: \(error.localizedDescription)"
        }
    }


    private func executeSelectiveImport(
        backup: DataPortService.KumaBackup,
        selectedWorkspaces: Set<UUID>,
        selectedServices: Set<UUID>
    ) {
        isProcessing = true
        Task {
            do {
                let dataPort = DataPortRepository()
                try await dataPort.importSelective(
                    from: backup,
                    selectedWorkspaceIDs: selectedWorkspaces,
                    selectedServiceIDs: selectedServices
                )

                workspaceStore.loadFromDatabase()
                isProcessing = false
                alertMessage = "Backup successfully imported (\(selectedWorkspaces.count) workspaces, \(selectedServices.count) services restored)!"
            } catch {
                isProcessing = false
                alertMessage = "Failed to import backup: \(error.localizedDescription)"
            }
        }
    }

    private func resetData() {
        isProcessing = true
        Task {
            await DataPortService.resetAllAppStorage()
            workspaceStore.loadFromDatabase()
            coordinator.resetToOnboarding()
            isProcessing = false
            openWindow(id: "onboarding")
            dismissWindow(id: "main-workspace")
        }
    }
}
