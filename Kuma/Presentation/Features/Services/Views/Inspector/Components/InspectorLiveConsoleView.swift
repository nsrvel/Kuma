import SwiftUI

/// Minimal live log lines for Service Inspector (reset baseline — no chrome).
public struct InspectorLiveConsoleView: View {
    public let serviceID: UUID
    public let service: Service
    public let provider: Provider
    public let isRunning: Bool

    @Bindable private var session = LiveLogSession.shared

    public init(
        serviceID: UUID,
        service: Service,
        provider: Provider,
        isRunning: Bool
    ) {
        self.serviceID = serviceID
        self.service = service
        self.provider = provider
        self.isRunning = isRunning
    }

    private var lines: [LiveLogSession.LiveLogLine] {
        guard session.bufferedServiceID == serviceID else { return [] }
        return session.lines
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { line in
                    Text(line.text)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, KumaSpacing.lg)
            .padding(.vertical, KumaSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: LiveLogStreamKey(serviceID: serviceID, isRunning: isRunning)) {
            guard isRunning else {
                session.stop()
                return
            }
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
    }
}

private struct LiveLogStreamKey: Hashable {
    let serviceID: UUID
    let isRunning: Bool
}
