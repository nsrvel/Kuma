import SwiftUI

// MARK: - ServiceNonPortBadge

public struct ServiceNonPortBadge: View {
    public let category: ProviderCategory

    public init(category: ProviderCategory) {
        self.category = category
    }

    public var body: some View {
        let (icon, label) = metadata

        HStack(spacing: 3.5) {
            Image(systemName: icon)
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 5.5)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 3.5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        }
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
