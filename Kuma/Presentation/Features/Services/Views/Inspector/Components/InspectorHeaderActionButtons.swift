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
        let showsStop = showsStopChrome(for: runtime.status)
        let isBusy = runtime.isLoading || runtime.status == .starting || runtime.status == .stopping

        Button {
            guard !isBusy else { return }
            KumaHapticManager.shared.tap()
            onToggle()
        } label: {
            HStack(spacing: 5) {
                if isBusy {
                    KumaActivityIndicator(size: 11, color: .white, lineWidth: 1.5)
                }
                Text(showsStop ? "Stop" : "Start")
                    .frame(minWidth: 34, alignment: .center)
                    .contentTransition(.interpolate)
            }
        }
        .buttonStyle(KumaPrimaryButtonStyle.inspectorToggle(isRunning: showsStop))
        .allowsHitTesting(!isBusy)
        .padding(.trailing, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(isBusy ? nil : .easeInOut(duration: 0.18), value: showsStop)
    }

    private func showsStopChrome(for status: ServiceState) -> Bool {
        switch status {
        case .running, .starting, .stopping:
            return true
        case .stopped, .crashed:
            return false
        }
    }
}
