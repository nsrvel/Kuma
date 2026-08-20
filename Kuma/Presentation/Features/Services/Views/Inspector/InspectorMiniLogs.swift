import SwiftUI

/// Fixed bottom dock zone of the Service Inspector.
/// Displays a mini terminal console for live log output with auto-scroll.
public struct InspectorMiniLogs: View {
    public let serviceID: UUID
    public let isRunning: Bool
    @State private var logs: [String] = []

    public init(serviceID: UUID, isRunning: Bool) {
        self.serviceID = serviceID
        self.isRunning = isRunning
    }

    public var body: some View {
        KumaFormSection(
            icon: "terminal.fill",
            title: "Live Logs"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                // Header status and clear action
                HStack(spacing: 6) {
                    Circle()
                        .fill(isRunning ? Color.green : Color.secondary.opacity(0.35))
                        .frame(width: 6, height: 6)

                    Text(isRunning ? "Stream Active" : "Stream Idle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isRunning ? Color.green : Color.secondary)

                    Spacer()

                    if !logs.isEmpty {
                        Button {
                            logs.removeAll()
                        } label: {
                            Text("Clear")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Console surface
                ZStack {
                    RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                        .fill(Color.black.opacity(0.25))
                        .overlay {
                            RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        }

                    if logs.isEmpty {
                        Text(isRunning ? "Waiting for output…" : "Start the service to view logs")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(Array(logs.enumerated()), id: \.offset) { idx, line in
                                        Text(line)
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(line.contains("[ERR]") ? Color.red.opacity(0.85) : .white.opacity(0.7))
                                            .textSelection(.enabled)
                                            .id(idx)
                                    }
                                }
                                .padding(8)
                            }
                            .onChange(of: logs.count) { _, _ in
                                if let last = logs.indices.last {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        proxy.scrollTo(last, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: 170)
            }
        }
    }
}

