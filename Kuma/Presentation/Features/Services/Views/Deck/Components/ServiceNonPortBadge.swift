import SwiftUI

// MARK: - ServiceNonPortBadge

public struct ServiceNonPortBadge: View {
    public let category: ProviderCategory

    public init(category: ProviderCategory) {
        self.category = category
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.2.layers.3d.bottom.filled")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)

            Text(category.sidebarLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .fixedSize()
    }

    private var metadata: (icon: String, label: String) {
        switch category {
        case .httpCheck:
            return ("waveform.path.ecg", "Health Check")
        case .shell:
            return ("terminal", "Shell")
        case .processMonitor:
            return ("cpu", "Process Monitor")
        case .docker:
            return ("shippingbox.fill", "Docker")
        case .podman:
            return ("cylinder.split.1x2.fill", "Podman")
        case .ssh:
            return ("server.rack", "SSH")
        case .tunnel:
            return ("cloud", "Tunnel")
        case .kubernetes:
            return ("network", "Kubernetes")
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        ServiceNonPortBadge(category: .docker)
        ServiceNonPortBadge(category: .shell)
        ServiceNonPortBadge(category: .httpCheck)
    }
    .padding()
}
