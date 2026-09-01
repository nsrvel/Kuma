import SwiftUI

/// Feature: Live Logs
/// Aggregated real-time log streaming viewer across all running services in active workspace.
public struct LiveLogsView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @State private var filterQuery: String = ""
    @State private var selectedServiceFilter: String = "All"
    @State private var isAutoScroll: Bool = true

    private var logAggregator: LogAggregator {
        LogAggregator.shared
    }

    public init() {}

    private var filteredLogs: [LiveLogEntry] {
        var list = logAggregator.entries
        if selectedServiceFilter != "All" {
            list = list.filter { $0.serviceName == selectedServiceFilter }
        }
        let query = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter { $0.message.lowercased().contains(query) || $0.serviceName.lowercased().contains(query) }
        }
        return list
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            HStack(spacing: 12) {
                KumaSearchField(text: $filterQuery, prompt: "Filter logs by text or regex…")
                    .frame(maxWidth: 320)

                let availableServices = Array(Set(logAggregator.entries.map(\.serviceName))).sorted()
                Picker("Service", selection: $selectedServiceFilter) {
                    Text("All Services").tag("All")
                    ForEach(availableServices, id: \.self) { srv in
                        Text(srv).tag(srv)
                    }
                }
                .frame(width: 150)

                Spacer()

                Toggle("Auto-scroll", isOn: $isAutoScroll)
                    .toggleStyle(.checkbox)
                    .font(KumaFont.caption)

                Button {
                    logAggregator.clear()
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

                if filteredLogs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("No live logs yet")
                            .font(KumaFont.body)
                            .foregroundStyle(.secondary)
                        Text("Start a service to stream real-time logs here.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(filteredLogs) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(item.timestamp)
                                        .foregroundStyle(.secondary.opacity(0.7))
                                        .frame(width: 65, alignment: .leading)

                                    Text(item.serviceName)
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
        }
        .navigationTitle("Live Logs")
        .background(KumaColors.canvasBackground)
    }
}
