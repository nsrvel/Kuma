import SwiftUI

/// Dedicated full-height live terminal log viewport for Service Inspector.
public struct InspectorLiveConsoleView: View {
    public let serviceID: UUID
    public let serviceName: String
    public let isRunning: Bool

    @State private var isAutoScroll: Bool = true
    @State private var copiedRecently: Bool = false

    private var logAggregator: LogAggregator {
        LogAggregator.shared
    }

    private var serviceLogs: [LiveLogEntry] {
        let list = logAggregator.logs(for: serviceID)
        if list.isEmpty && isRunning {
            return [
                LiveLogEntry(serviceID: serviceID, serviceName: serviceName, timestamp: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium), level: "INFO", message: "Process runner initialized (Awaiting output)")
            ]
        }
        if list.count > 300 {
            return Array(list.suffix(300))
        }
        return list
    }

    public init(serviceID: UUID, serviceName: String, isRunning: Bool) {
        self.serviceID = serviceID
        self.serviceName = serviceName
        self.isRunning = isRunning
    }

    public var body: some View {
        let logs = serviceLogs
        ZStack {
            if logs.isEmpty && !isRunning {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("No logs available")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Start the service to observe real-time terminal output.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(KumaSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3.5) {
                            ForEach(logs) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(item.timestamp)
                                        .foregroundStyle(Color.secondary.opacity(0.6))
                                        .frame(width: 55, alignment: .leading)

                                    Text(item.level)
                                        .foregroundStyle(levelColor(for: item.level))
                                        .frame(width: 34, alignment: .leading)

                                    Text(item.message)
                                        .foregroundStyle(Color.primary.opacity(0.92))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .textSelection(.enabled)
                    .onChange(of: logs.count) { _, _ in
                        if isAutoScroll, let last = logs.last {
                            withAnimation(.easeOut(duration: 0.12)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func levelColor(for level: String) -> Color {
        switch level.uppercased() {
        case "ERR", "ERROR":
            return Color.red
        case "WARN", "WARNING":
            return Color.orange
        case "OK", "SUCCESS":
            return Color.green
        default:
            return Color.cyan.opacity(0.85)
        }
    }
}
