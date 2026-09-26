import SwiftUI

/// Dedicated full-height live terminal log viewport for Service Inspector.
public struct InspectorLiveConsoleView: View {
    private static let awaitingOutputPlaceholderID = UUID(uuidString: "E7A1C4B2-9F3D-4A1E-8C0B-000000000001")!

    public let serviceID: UUID
    public let serviceName: String
    public let isRunning: Bool

    @State private var logAggregator = LogAggregator.shared
    @State private var isAutoScroll: Bool = true

    private static func awaitingOutputEntry(serviceID: UUID, serviceName: String) -> LiveLogEntry {
        LiveLogEntry(
            id: awaitingOutputPlaceholderID,
            serviceID: serviceID,
            serviceName: serviceName,
            timestamp: "—",
            level: "INFO",
            message: "Process runner initialized (Awaiting output)"
        )
    }

    private var serviceLogs: [LiveLogEntry] {
        let list = logAggregator.logs(for: serviceID)
        if list.isEmpty && isRunning {
            return [Self.awaitingOutputEntry(serviceID: serviceID, serviceName: serviceName)]
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
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Toggle("Auto-scroll", isOn: $isAutoScroll)
                    .toggleStyle(.checkbox)
                    .font(KumaFont.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            logAggregator.retainUISubscriber()
            defer { logAggregator.releaseUISubscriber() }
        }
    }
}
