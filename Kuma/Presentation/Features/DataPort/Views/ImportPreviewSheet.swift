import SwiftUI

public struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let backup: DataPortService.KumaBackup
    public let fileName: String
    public let existingWorkspaceIDs: Set<UUID>
    public let onConfirmImport: (_ selectedWorkspaceIDs: Set<UUID>, _ selectedServiceIDs: Set<UUID>) -> Void

    @State private var tableRows: [FullImportTableRow] = []
    @State private var selectedRowIDs: Set<UUID> = []
    @State private var focusedRowID: UUID? = nil
    @State private var searchText: String = ""

    public init(
        backup: DataPortService.KumaBackup,
        fileName: String,
        existingWorkspaceIDs: Set<UUID>,
        onConfirmImport: @escaping (Set<UUID>, Set<UUID>) -> Void
    ) {
        self.backup = backup
        self.fileName = fileName
        self.existingWorkspaceIDs = existingWorkspaceIDs
        self.onConfirmImport = onConfirmImport
    }

    private var filteredRows: [FullImportTableRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tableRows }
        return tableRows.filter { row in
            row.serviceName.lowercased().contains(query) ||
            row.workspaceName.lowercased().contains(query) ||
            row.providerCategory.sidebarLabel.lowercased().contains(query) ||
            row.target.lowercased().contains(query)
        }
    }

    private var currentInspectedRow: FullImportTableRow? {
        if let focusedRowID {
            return tableRows.first(where: { $0.id == focusedRowID })
        }
        return filteredRows.first
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header Bar with Native macOS Search Field
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.gradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Configuration")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(fileName) • \(backup.workspaces.count) workspaces, \(backup.services.count) services")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                KumaSearchField(text: $searchText, prompt: "Search services")
                    .frame(width: 180, height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider().opacity(0.4)

            // 2. Master-Detail Stage (Table on Left, Inspector on Right)
            HSplitView {
                Table(filteredRows, selection: $focusedRowID) {
                    TableColumn("") { row in
                        Toggle("", isOn: Binding(
                            get: { selectedRowIDs.contains(row.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedRowIDs.insert(row.id)
                                } else {
                                    selectedRowIDs.remove(row.id)
                                }
                            }
                        ))
                        .labelsHidden()
                        .controlSize(.mini)
                    }
                    .width(28)

                    TableColumn("Name") { row in
                        Text(row.serviceName)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .width(min: 120, ideal: 150)


                    TableColumn("Workspace") { row in
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(row.workspaceName)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 95, ideal: 115)

                    TableColumn("Provider") { row in
                        Text(row.providerCategory.sidebarLabel)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.85))
                    }
                    .width(min: 75, ideal: 85)

                    TableColumn("Config") { row in
                        Text(row.target.isEmpty ? "—" : row.target)
                            .font(.system(size: 11, design: isMonospacedTarget(for: row.providerCategory) ? .monospaced : .default))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .width(min: 110, ideal: 140)

                    TableColumn("Status") { row in
                        if row.isExistingWorkspace {
                            Text("Merge")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                        } else {
                            Text("New")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.green.opacity(0.12), in: Capsule())
                        }
                    }
                    .width(55)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minWidth: 460, maxWidth: .infinity)

                // Detail Inspector Side Pane
                if let inspected = currentInspectedRow {
                    ImportDetailInspectorPane(
                        serviceName: inspected.serviceName,
                        serviceDescription: inspected.serviceDescription,
                        provider: inspected.provider,
                        portMappings: inspected.portMappings,
                        hasConflict: false
                    )
                    .frame(minWidth: 240, maxWidth: 290)
                }
            }
            .frame(height: 380)

            Divider().opacity(0.4)

            // 3. Footer Bar
            HStack(spacing: 12) {
                Button(selectedRowIDs.count == filteredRows.count && !filteredRows.isEmpty ? "Deselect All" : "Select All") {
                    if selectedRowIDs.count == filteredRows.count && !filteredRows.isEmpty {
                        selectedRowIDs.removeAll()
                    } else {
                        selectedRowIDs = Set(filteredRows.map(\.id))
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.accentColor)

                Spacer()

                Text("\(selectedRowIDs.count) of \(tableRows.count) selected\(filteredRows.count != tableRows.count ? " (\(filteredRows.count) matching)" : "")")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Import Selected") {
                    confirmAndImport()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRowIDs.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 820, height: 500)
        .onAppear {
            buildRows()
        }
    }

    private func confirmAndImport() {
        let selectedRows = tableRows.filter { selectedRowIDs.contains($0.id) }
        let selectedWS = Set(selectedRows.map(\.workspaceID))
        onConfirmImport(selectedWS, selectedRowIDs)
    }

    // MARK: - Row Builder

    private func buildRows() {
        var rows: [FullImportTableRow] = []
        let workspaceMap = Dictionary(uniqueKeysWithValues: backup.workspaces.map { ($0.id, $0) })

        for service in backup.services {
            let ws = service.workspaceID.flatMap { workspaceMap[$0] }
            let wsName = ws?.name ?? "Default Workspace"
            let wsID = ws?.id ?? (backup.workspaces.first?.id ?? UUID())
            let isExisting = existingWorkspaceIDs.contains(wsID)

            let provider = backup.providers.first(where: { $0.serviceID == service.id })
            let category = provider?.category ?? .docker
            let targetString = provider?.resolvedTarget ?? ""
            let ports = backup.portMappings.filter { $0.providerID == provider?.id || $0.providerID == service.id }

            rows.append(
                FullImportTableRow(
                    id: service.id,
                    serviceName: service.name,
                    serviceDescription: service.description,
                    workspaceName: wsName,
                    workspaceID: wsID,
                    providerCategory: category,
                    target: targetString,
                    isExistingWorkspace: isExisting,
                    provider: provider,
                    portMappings: ports
                )
            )
        }

        self.tableRows = rows
        self.selectedRowIDs = Set(rows.map(\.id))
        self.focusedRowID = rows.first?.id
    }

    private func isMonospacedTarget(for category: ProviderCategory) -> Bool {
        switch category {
        case .docker, .podman, .kubernetes, .shell, .ssh: return true
        default: return false
        }
    }
}
