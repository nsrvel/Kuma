import SwiftUI

/// Feature: Live Logs
/// Aggregated real-time log streaming viewer across all running services in active workspace.
public struct LiveLogsView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @State private var filterQuery: String = ""
    @State private var selectedServiceFilter: String = "All"
    @State private var isAutoScroll: Bool = true

    // Sample aggregated logs
    private let sampleLogs: [(timestamp: String, service: String, level: String, message: String)] = [
        ("16:40:12", "frontend-app", "INFO", "Next.js dev server ready on http://localhost:3000"),
        ("16:40:15", "postgres-db", "INFO", "database system is ready to accept connections"),
        ("16:40:18", "api-gateway", "WARN", "Connecting to auth-service on retry attempt 1/3"),
        ("16:40:22", "api-gateway", "INFO", "Connected to auth-service successfully (23ms)"),
        ("16:41:00", "redis-cache", "INFO", "Ready to accept connections tcp"),
        ("16:41:05", "api-gateway", "ERR", "HTTP 500 GET /api/v1/checkout - Payment gateway timeout"),
        ("16:41:10", "frontend-app", "INFO", "GET /cart 200 in 142ms")
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            HStack(spacing: 12) {
                KumaSearchField(text: $filterQuery, prompt: "Filter logs by text or regex…")
                    .frame(maxWidth: 320)


                Picker("Service", selection: $selectedServiceFilter) {
                    Text("All Services").tag("All")
                    Text("frontend-app").tag("frontend-app")
                    Text("postgres-db").tag("postgres-db")
                    Text("api-gateway").tag("api-gateway")
                }
                .frame(width: 150)

                Spacer()

                Toggle("Auto-scroll", isOn: $isAutoScroll)
                    .toggleStyle(.checkbox)
                    .font(KumaFont.caption)

                Button {
                    // Clear buffer
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(KumaColors.canvasBackground)

            Divider().opacity(0.4)

            // Terminal Log Viewer
            ZStack {
                Color.black.opacity(0.85)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(sampleLogs.indices, id: \.self) { idx in
                            let item = sampleLogs[idx]
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.timestamp)
                                    .foregroundStyle(.secondary.opacity(0.7))
                                    .frame(width: 65, alignment: .leading)

                                Text(item.service)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 95, alignment: .leading)

                                Text(item.level)
                                    .foregroundStyle(item.level == "ERR" ? Color.red : (item.level == "WARN" ? Color.orange : Color.green))
                                    .frame(width: 40, alignment: .leading)

                                Text(item.message)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .font(.system(size: 11.5, design: .monospaced))
                            .textSelection(.enabled)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .navigationTitle("Live Logs")
        .background(KumaColors.canvasBackground)
    }
}
