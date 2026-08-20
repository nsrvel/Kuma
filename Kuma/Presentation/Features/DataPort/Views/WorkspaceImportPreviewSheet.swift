import SwiftUI

public struct WorkspaceImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let backup: DataPortService.KumaBackup
    public let fileName: String
    public let targetWorkspaceName: String
    public let targetWorkspaceID: UUID
    public let existingServiceNames: Set<String>
    public let onConfirmImport: (_ selectedServiceIDs: Set<UUID>, _ resolvedNames: [UUID: String]) -> Void

    @State private var tableRows: [ServiceImportRow] = []
    @State private var selectedRowIDs: Set<UUID> = []
    @State private var renamedOverrides: [UUID: String] = [:]
    @State private var focusedRowID: UUID? = nil
    @State private var searchText: String = ""

    public init(
        backup: DataPortService.KumaBackup,
        fileName: String,
        targetWorkspaceName: String,
        targetWorkspaceID: UUID,
        existingServiceNames: Set<String> = [],
        onConfirmImport: @escaping (Set<UUID>, [UUID: String]) -> Void
    ) {
        self.backup = backup
        self.fileName = fileName
        self.targetWorkspaceName = targetWorkspaceName
        self.targetWorkspaceID = targetWorkspaceID
        self.existingServiceNames = existingServiceNames
        self.onConfirmImport = onConfirmImport
    }

    private var filteredRows: [ServiceImportRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tableRows }
        return tableRows.filter { row in
            row.serviceName.lowercased().contains(query) ||
            row.providerCategory.sidebarLabel.lowercased().contains(query) ||
            row.target.lowercased().contains(query)
        }
    }

    private var currentInspectedRow: ServiceImportRow? {
        if let focusedRowID {
            return tableRows.first(where: { $0.id == focusedRowID })
        }
        return filteredRows.first
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header Bar with Search
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
                    Text("Import Services into “\(targetWorkspaceName)”")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(fileName) • \(backup.services.count) services found in backup")
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
                        HStack(spacing: 6) {
                            Text(renamedOverrides[row.id] ?? row.serviceName)
                                .font(.system(size: 12, weight: .semibold))

                            if row.hasConflict {
                                Text("Name Exists")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Color.orange.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .width(min: 130, ideal: 160)


                    TableColumn("Provider") { row in
                        Text(row.providerCategory.sidebarLabel)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.85))
                    }
                    .width(min: 80, ideal: 95)

                    TableColumn("Config") { row in
                        Text(row.target.isEmpty ? "—" : row.target)
                            .font(.system(size: 11, design: isMonospacedTarget(for: row.providerCategory) ? .monospaced : .default))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .width(min: 130, ideal: 180)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minWidth: 440, maxWidth: .infinity)

                // Detail Inspector Side Pane
                if let inspected = currentInspectedRow {
                    ImportDetailInspectorPane(
                        serviceName: renamedOverrides[inspected.id] ?? inspected.serviceName,
                        serviceDescription: inspected.serviceDescription,
                        provider: inspected.provider,
                        portMappings: inspected.portMappings,
                        hasConflict: inspected.hasConflict
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
        .frame(width: 800, height: 500)
        .onAppear {
            buildRows()
        }
    }

    private func confirmAndImport() {
        onConfirmImport(selectedRowIDs, renamedOverrides)
    }

    // MARK: - Row Builder with Target Resolution & Conflict Detection

    private func buildRows() {
        var rows: [ServiceImportRow] = []
        var renames: [UUID: String] = [:]

        for service in backup.services {
            let provider = backup.providers.first(where: { $0.serviceID == service.id })
            let category = provider?.category ?? .docker
            let targetString = provider?.resolvedTarget ?? ""
            let ports = backup.portMappings.filter { $0.providerID == provider?.id || $0.providerID == service.id }

            let hasConflict = existingServiceNames.contains(service.name.lowercased())
            if hasConflict {
                renames[service.id] = "\(service.name) (Imported)"
            }

            rows.append(
                ServiceImportRow(
                    id: service.id,
                    serviceName: service.name,
                    serviceDescription: service.description,
                    providerCategory: category,
                    target: targetString,
                    hasConflict: hasConflict,
                    provider: provider,
                    portMappings: ports
                )
            )
        }

        self.tableRows = rows
        self.renamedOverrides = renames
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
