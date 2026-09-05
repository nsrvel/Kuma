import SwiftUI

public struct InspectorOptionsSection: View {
    @Binding public var isDisabled: Bool
    public let isRunning: Bool
    public let isEditing: Bool
    public let onDelete: () -> Void

    public init(
        isDisabled: Binding<Bool>,
        isRunning: Bool = false,
        isEditing: Bool = true,
        onDelete: @escaping () -> Void
    ) {
        self._isDisabled = isDisabled
        self.isRunning = isRunning
        self.isEditing = isEditing
        self.onDelete = onDelete
    }

    public var body: some View {
        KumaFormSection(
            icon: "gearshape.fill",
            title: "Options"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                // Disable Service
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disable Service")
                            .font(KumaFont.body)
                        Text(isRunning ? "Stop the service before disabling." : "When disabled, this service is locked and excluded from bulk operations.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $isDisabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .disabled(isRunning)
                }

                Divider().opacity(0.4)

                // Delete Service
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Service")
                            .font(KumaFont.body)
                            .foregroundStyle(.red)
                        Text(isRunning ? "Stop the service before deleting." : "Permanently remove this service.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                    .disabled(isRunning)
                }
            }
        }
    }
}

// MARK: - Inspector Live Console View

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
        let entries = logAggregator.entries.filter { $0.serviceID == serviceID }
        if entries.isEmpty && isRunning {
            return [
                LiveLogEntry(serviceID: serviceID, serviceName: serviceName, timestamp: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium), level: "INFO", message: "Process runner initialized (Awaiting output)")
            ]
        }
        return entries
    }

    public init(serviceID: UUID, serviceName: String, isRunning: Bool) {
        self.serviceID = serviceID
        self.serviceName = serviceName
        self.isRunning = isRunning
    }

    public var body: some View {
        ZStack {
            if serviceLogs.isEmpty && !isRunning {
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
                            ForEach(serviceLogs) { item in
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
                    .onChange(of: serviceLogs.count) { _, _ in
                        if isAutoScroll, let last = serviceLogs.last {
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





