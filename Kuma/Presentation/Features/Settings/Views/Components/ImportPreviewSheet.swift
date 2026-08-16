import SwiftUI

public struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let backup: DataPortService.KumaBackup
    public let fileName: String
    public let existingWorkspaceIDs: Set<UUID>
    public let onConfirmImport: (_ selectedWorkspaceIDs: Set<UUID>, _ selectedServiceIDs: Set<UUID>) -> Void

    public struct ImportTableRow: Identifiable {
        public let id: UUID
        public let serviceName: String
        public let workspaceName: String
        public let workspaceID: UUID
        public let providerType: String
        public let target: String
        public let isExistingWorkspace: Bool
    }

    @State private var tableRows: [ImportTableRow] = []
    @State private var selectedRowIDs: Set<UUID> = []

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

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header Bar
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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .opacity(0.4)

            // 2. Table Data Stage
            Table(tableRows) {
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
                        .font(.system(size: 12, weight: .medium))
                }
                .width(min: 130, ideal: 150)

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
                .width(min: 110, ideal: 130)

                TableColumn("Provider") { row in
                    Text(row.providerType)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .width(min: 75, ideal: 90)

                TableColumn("Config") { row in
                    Text(row.target.isEmpty ? "—" : row.target)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .width(min: 180, ideal: 240)

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
            .frame(height: 380)

            Divider()
                .opacity(0.4)

            // 3. Footer Bar
            HStack(spacing: 12) {
                Button(selectedRowIDs.count == tableRows.count ? "Deselect All" : "Select All") {
                    if selectedRowIDs.count == tableRows.count {
                        selectedRowIDs.removeAll()
                    } else {
                        selectedRowIDs = Set(tableRows.map(\.id))
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.accentColor)

                Spacer()

                Text("\(selectedRowIDs.count) of \(tableRows.count) selected")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Import Selected") {
                    let selectedRows = tableRows.filter { selectedRowIDs.contains($0.id) }
                    let selectedWS = Set(selectedRows.map(\.workspaceID))
                    onConfirmImport(selectedWS, selectedRowIDs)
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
        .frame(width: 740, height: 520)
        .onAppear {
            buildRows()
        }
    }

    // MARK: - Row Builder

    private func buildRows() {
        var rows: [ImportTableRow] = []
        let workspaceMap = Dictionary(uniqueKeysWithValues: backup.workspaces.map { ($0.id, $0) })

        for service in backup.services {
            let ws = service.workspaceID.flatMap { workspaceMap[$0] }
            let wsName = ws?.name ?? "Default Workspace"
            let wsID = ws?.id ?? (backup.workspaces.first?.id ?? UUID())
            let isExisting = existingWorkspaceIDs.contains(wsID)

            let provider = backup.providers.first(where: { $0.serviceID == service.id })
            let providerTypeFormatted = formatProviderType(provider?.type)
            let targetString = provider?.targetName ?? provider?.runCommand ?? provider?.yamlConfig ?? ""

            rows.append(
                ImportTableRow(
                    id: service.id,
                    serviceName: service.name,
                    workspaceName: wsName,
                    workspaceID: wsID,
                    providerType: providerTypeFormatted,
                    target: targetString,
                    isExistingWorkspace: isExisting
                )
            )
        }

        self.tableRows = rows
        self.selectedRowIDs = Set(rows.map(\.id))
    }

    private func formatProviderType(_ type: String?) -> String {
        guard let type else { return "Docker" }
        switch type {
        case "kube_port_forward", "kubernetes":   return "Kubernetes"
        case "docker":                            return "Docker"
        case "podman":                            return "Podman"
        case "shell":                             return "Shell"
        case "ssh":                               return "SSH"
        case "http_check", "httpCheck":           return "HTTP"
        case "tunnel":                            return "Tunnel"
        case "process_monitor", "processMonitor": return "Process"
        default:                                  return "Docker"
        }
    }
}
