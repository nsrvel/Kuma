import SwiftUI

/// Feature: Port Registry
/// Displays all mapped and active localhost ports across services and detects port conflicts.
public struct PortRegistryView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @State private var searchText: String = ""
    @State private var portMappings: [ServicePortMapping] = []
    @State private var serviceNames: [UUID: String] = [:]
    @State private var isLoading: Bool = false

    private let serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()

    public init() {}

    private var conflictPortSet: Set<Int> {
        let ports = portMappings.map(\.localPort)
        var seen = Set<Int>()
        var duplicates = Set<Int>()
        for p in ports {
            if seen.contains(p) {
                duplicates.insert(p)
            } else {
                seen.insert(p)
            }
        }
        return duplicates
    }

    private var filteredPorts: [ServicePortMapping] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return portMappings.sorted { $0.localPort < $1.localPort }
        }
        return portMappings.filter { mapping in
            let portStr = "\(mapping.localPort)"
            let srvName = mapping.serviceID.flatMap { serviceNames[$0] }?.lowercased() ?? ""
            return portStr.contains(query) || srvName.contains(query)
        }.sorted { $0.localPort < $1.localPort }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                KumaSearchField(text: $searchText, prompt: "Search port or service name…")
                    .frame(maxWidth: 280)

                Spacer()

                if !conflictPortSet.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 7, height: 7)
                        Text("\(conflictPortSet.count) Conflict\(conflictPortSet.count > 1 ? "s" : "") Detected")
                            .font(KumaFont.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                }

                Button {
                    loadPorts()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Scan Ports")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(KumaColors.canvasBackground)

            Divider().opacity(0.4)

            // Ports Table / List
            ScrollView {
                if filteredPorts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("No ports configured")
                            .font(KumaFont.body)
                            .foregroundStyle(.secondary)
                        Text("Add port mappings to your services to monitor them here.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding(32)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredPorts) { item in
                            let srvName = item.serviceID.flatMap { serviceNames[$0] } ?? "Service"
                            let isConflict = conflictPortSet.contains(item.localPort)
                            PortRowCard(
                                port: item.localPort,
                                service: srvName,
                                provider: "\(item.protocolType) Forward",
                                status: isConflict ? "Conflict Detected" : "Configured",
                                pid: "-"
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            loadPorts()
        }
        .navigationTitle("Port Registry")
        .background(KumaColors.canvasBackground)
    }

    private func loadPorts() {
        Task {
            do {
                let mappings = try await serviceRepository.fetchAllPortMappings()
                self.portMappings = mappings
                for ws in workspaceStore.workspaces {
                    let snapshots = try await serviceRepository.fetchSnapshots(forWorkspace: ws.id)
                    for s in snapshots {
                        serviceNames[s.id] = s.name
                    }
                }
            } catch {
                // handle gracefully
            }
        }
    }
}

private struct PortRowCard: View {
    let port: Int
    let service: String
    let provider: String
    let status: String
    let pid: String

    private var isConflict: Bool { status.contains("Conflict") }

    var body: some View {
        HStack(spacing: 14) {
            // Port badge
            Text(":\(port)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(isConflict ? Color.red : Color.accentColor)
                .frame(width: 65, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(service)
                    .font(KumaFont.bodyBold)
                    .foregroundStyle(.primary)

                Text(provider)
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if pid != "-" {
                Text("PID \(pid)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            // Status chip
            Text(status)
                .font(KumaFont.captionBold)
                .foregroundStyle(isConflict ? Color.red : (status == "In Use" ? Color.green : Color.secondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    (isConflict ? Color.red : (status == "In Use" ? Color.green : Color.secondary)).opacity(0.12),
                    in: Capsule()
                )

            Button {
                if let url = URL(string: "http://localhost:\(port)") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "safari")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Open in Browser (http://localhost:\(port))")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(KumaColors.surfaceBackground, in: RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                .stroke(isConflict ? Color.red.opacity(0.4) : KumaColors.inputBorder, lineWidth: isConflict ? 1 : 0.5)
        )
    }
}
