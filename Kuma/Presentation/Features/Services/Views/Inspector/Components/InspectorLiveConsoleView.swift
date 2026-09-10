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
                KumaLogConsoleView(
                    entries: logs,
                    isAutoScroll: isAutoScroll,
                    emptyPlaceholder: "Awaiting service logs..."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
