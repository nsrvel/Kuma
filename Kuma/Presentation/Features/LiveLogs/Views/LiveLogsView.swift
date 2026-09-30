import SwiftUI

/// Feature: Live Logs
/// Aggregated real-time log streaming viewer across all running services in active workspace.
public struct LiveLogsView: View {
    @State private var logAggregator = LogAggregator.shared
    @State private var filterQuery: String = ""
    @State private var debouncedQuery: String = ""
    @State private var selectedServiceFilter: String = "All"
    @State private var isAutoScroll: Bool = true
    @State private var debounceTask: Task<Void, Never>? = nil

    public init() {}

    private var filteredLogs: [LiveLogEntry] {
        var list = logAggregator.entries
        if selectedServiceFilter != "All" {
            list = list.filter { $0.serviceName == selectedServiceFilter }
        }
        let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter {
                LiveLogTextMatcher.matches($0.message, query: query)
                    || LiveLogTextMatcher.matches($0.serviceName, query: query)
            }
        }
        return list
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                KumaSearchField(text: $filterQuery, prompt: "Filter logs (substring or /regex/)…")
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
                    ForEach(logAggregator.availableServiceNames, id: \.self) { srv in
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
        .task {
            logAggregator.retainUISubscriber()
            defer { logAggregator.releaseUISubscriber() }
        }
    }
}
