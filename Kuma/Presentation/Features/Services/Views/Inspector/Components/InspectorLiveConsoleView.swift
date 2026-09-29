import SwiftUI

/// Dedicated full-height live terminal log viewport for Service Inspector.
public struct InspectorLiveConsoleView: View {
    public let serviceID: UUID
    public let service: Service
    public let provider: Provider
    public let isRunning: Bool

    @Binding var isLogAutoScrollEnabled: Bool
    @Binding var logWrapsLines: Bool
    @Binding var logScrollToBottomRequest: Int

    @State private var session = LiveLogSession.shared
    @State private var trimNoticeDismissed = false

    public init(
        serviceID: UUID,
        serviceName: String,
        service: Service,
        provider: Provider,
        isRunning: Bool,
        isLogAutoScrollEnabled: Binding<Bool>,
        logWrapsLines: Binding<Bool>,
        logScrollToBottomRequest: Binding<Int>
    ) {
        self.serviceID = serviceID
        self.service = service
        self.provider = provider
        self.isRunning = isRunning
        self._isLogAutoScrollEnabled = isLogAutoScrollEnabled
        self._logWrapsLines = logWrapsLines
        self._logScrollToBottomRequest = logScrollToBottomRequest
    }

    private var entries: [LiveLogEntry] {
        guard session.bufferedServiceID == serviceID else { return [] }
        return session.lines.map { line in
            LiveLogEntry(
                id: line.id,
                serviceID: serviceID,
                serviceName: "",
                message: line.text
            )
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            if session.didTrimToMaxLines && !trimNoticeDismissed {
                HStack {
                    Text("Showing last 1,000 lines")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("OK") {
                        trimNoticeDismissed = true
                        session.acknowledgeTrimNotice()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10.5, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            ZStack {
                if entries.isEmpty && !isRunning {
                    VStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("No logs available")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Start the service to stream live output here.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(KumaSpacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    KumaLogConsoleView(
                        entries: entries,
                        isAutoScroll: isLogAutoScrollEnabled,
                        wrapsLines: logWrapsLines,
                        emptyPlaceholder: "Awaiting service logs...",
                        scrollToBottomRequest: logScrollToBottomRequest,
                        onUserScrolledAwayFromBottom: {
                            if isLogAutoScrollEnabled {
                                isLogAutoScrollEnabled = false
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: LiveLogStreamKey(serviceID: serviceID, isRunning: isRunning)) {
            guard isRunning else {
                session.stop()
                return
            }
            trimNoticeDismissed = false
            session.start(serviceID: serviceID, service: service, provider: provider)
            defer {
                session.stop()
                if session.bufferedServiceID == serviceID {
                    session.clear()
                }
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .onChange(of: session.didTrimToMaxLines) { _, trimmed in
            if trimmed { trimNoticeDismissed = false }
        }
    }
}

private struct LiveLogStreamKey: Hashable {
    let serviceID: UUID
    let isRunning: Bool
}
