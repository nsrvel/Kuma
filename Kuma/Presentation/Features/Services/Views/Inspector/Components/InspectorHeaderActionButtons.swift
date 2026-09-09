import SwiftUI

/// Header action button and log control buttons for InspectorStatusHeader.
public struct InspectorHeaderLogControls: View {
    public let serviceID: UUID
    @State private var copiedRecently: Bool = false

    public init(serviceID: UUID) {
        self.serviceID = serviceID
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button {
                copyLogs()
            } label: {
                HStack(spacing: 3.5) {
                    Image(systemName: copiedRecently ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                    Text(copiedRecently ? "Copied" : "Copy")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Copy logs to clipboard")

            Button {
                LogAggregator.shared.clear(serviceID: serviceID)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4.5)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear logs for this service")
            .help("Clear logs")
        }
        .padding(.trailing, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func copyLogs() {
        let entries = LogAggregator.shared.logs(for: serviceID)
        let content = entries.map { "[\($0.timestamp)] [\($0.level)] \($0.message)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)

        withAnimation {
            copiedRecently = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                copiedRecently = false
            }
        }
    }
}

public struct InspectorHeaderActionButton: View {
    public let runtime: ServiceRuntimeState
    public let onToggle: () -> Void

    public init(runtime: ServiceRuntimeState, onToggle: @escaping () -> Void) {
        self.runtime = runtime
        self.onToggle = onToggle
    }

    public var body: some View {
        let isRunning = runtime.status.isOperational
        let tintColor: Color = isRunning ? .red : .green

        Button {
            onToggle()
        } label: {
            HStack(spacing: 5) {
                if runtime.isLoading || runtime.status == .starting || runtime.status == .stopping {
                    KumaActivityIndicator(size: 11, color: tintColor, lineWidth: 1.5)
                }
                Text(isRunning ? "Stop" : "Start")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(tintColor)
            .frame(minWidth: 56)
            .padding(.horizontal, 16)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tintColor.opacity(0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(tintColor.opacity(0.35), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(runtime.isLoading || runtime.status == .starting || runtime.status == .stopping)
        .padding(.trailing, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
