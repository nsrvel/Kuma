import SwiftUI

public struct WorkspaceImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let backup: DataPortService.KumaBackup
    public let fileName: String
    public let targetWorkspaceName: String
    public let targetWorkspaceID: UUID
    public let onConfirmImport: (_ selectedServiceIDs: Set<UUID>) -> Void

    public struct ServiceImportRow: Identifiable {
        public let id: UUID
        public let serviceName: String
        public let providerType: String
        public let target: String
    }

    @State private var tableRows: [ServiceImportRow] = []
    @State private var selectedRowIDs: Set<UUID> = []

    public init(
        backup: DataPortService.KumaBackup,
        fileName: String,
        targetWorkspaceName: String,
        targetWorkspaceID: UUID,
        onConfirmImport: @escaping (Set<UUID>) -> Void
    ) {
        self.backup = backup
        self.fileName = fileName
        self.targetWorkspaceName = targetWorkspaceName
        self.targetWorkspaceID = targetWorkspaceID
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
                    Text("Import Services into “\(targetWorkspaceName)”")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(fileName) • \(backup.services.count) services found in backup")
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
                .width(min: 140, ideal: 180)

                TableColumn("Provider") { row in
                    Text(row.providerType)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .width(min: 80, ideal: 100)

                TableColumn("Config") { row in
                    Text(row.target.isEmpty ? "—" : row.target)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .width(min: 220, ideal: 300)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(height: 360)

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
                    onConfirmImport(selectedRowIDs)
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
        .frame(width: 700, height: 500)
        .onAppear {
            buildRows()
        }
    }

    // MARK: - Row Builder

    private func buildRows() {
        var rows: [ServiceImportRow] = []

        for service in backup.services {
            let provider = backup.providers.first(where: { $0.serviceID == service.id })
            let providerTypeFormatted = formatProviderType(provider?.type)
            let targetString = provider?.targetName ?? provider?.runCommand ?? provider?.yamlConfig ?? ""

            rows.append(
                ServiceImportRow(
                    id: service.id,
                    serviceName: service.name,
                    providerType: providerTypeFormatted,
                    target: targetString
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
