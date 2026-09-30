import SwiftUI

/// Feature: Live Logs
/// Aggregated real-time log streaming viewer across all running services in active workspace.
public struct LiveLogsView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @State private var filterQuery: String = ""
    @State private var debouncedQuery: String = ""
    @State private var selectedServiceFilter: String = "All"
    @State private var isAutoScroll: Bool = true
    @State private var debounceTask: Task<Void, Never>? = nil

    private var logAggregator: LogAggregator {
        LogAggregator.shared
    }

    public init() {}

    private var availableServices: [String] {
        Array(Set(logAggregator.entries.map(\.serviceName))).sorted()
    }

    private var filteredLogs: [LiveLogEntry] {
        var list = logAggregator.entries
        if selectedServiceFilter != "All" {
            list = list.filter { $0.serviceName == selectedServiceFilter }
        }
        let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
                    .onChange(of: filterQuery) { _, newValue in
                        debounceTask?.cancel()
                        debounceTask = Task {
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            guard !Task.isCancelled else { return }
                            debouncedQuery = newValue
                        }
                    }

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

            // High-performance Native Terminal Log Console
            ZStack {
                Color.black.opacity(0.85)

                KumaLogConsoleView(
                    entries: filteredLogs,
                    isAutoScroll: isAutoScroll,
                    emptyPlaceholder: "No live logs yet.\nStart a service to stream real-time logs here."
                )
            }
        }
        .navigationTitle("Live Logs")
        .background(KumaColors.canvasBackground)
    }
}
