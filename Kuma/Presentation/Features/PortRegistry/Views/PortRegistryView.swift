import SwiftUI

/// Feature: Port Registry
/// Displays all mapped and active localhost ports across services and detects port conflicts.
public struct PortRegistryView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @State private var searchText: String = ""
    @State private var filterStatus: String = "All"

    // Mock ports for placeholder demonstration
    private let samplePorts: [(port: Int, service: String, provider: String, status: String, pid: String)] = [
        (3000, "frontend-app", "Docker Compose", "In Use", "14920"),
        (5432, "postgres-db", "Docker Compose", "In Use", "15002"),
        (6379, "redis-cache", "Kubernetes", "In Use", "15040"),
        (8080, "api-gateway", "Shell Script", "Conflict Detected", "16200"),
        (8080, "legacy-service", "SSH Remote", "Conflict Detected", "16215"),
        (9090, "prometheus", "Podman", "Idle", "-")
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                KumaSearchField(text: $searchText, prompt: "Search port, service, or PID…")
                    .frame(maxWidth: 280)


                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                    Text("1 Conflict Detected")
                        .font(KumaFont.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1), in: Capsule())

                Button {
                    // Refresh ports
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
                LazyVStack(spacing: 8) {
                    ForEach(samplePorts, id: \.port) { item in
                        PortRowCard(
                            port: item.port,
                            service: item.service,
                            provider: item.provider,
                            status: item.status,
                            pid: item.pid
                        )
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Port Registry")
        .background(KumaColors.canvasBackground)
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
