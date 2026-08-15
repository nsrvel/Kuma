import SwiftUI

public enum ProviderCategory: String, CaseIterable, Codable, Sendable, Hashable {
    case docker
    case kubernetes
    case podman
    case shell
    case ssh
    case httpCheck
    case tunnel
    case processMonitor

    // MARK: - Short Sidebar Display Name

    public nonisolated var sidebarLabel: String {
        switch self {
        case .docker:         return "Docker"
        case .kubernetes:     return "Kubernetes"
        case .podman:         return "Podman"
        case .shell:          return "Shell"
        case .ssh:            return "SSH"
        case .httpCheck:      return "Health Check"
        case .tunnel:         return "Tunnels"
        case .processMonitor: return "Processes"
        }
    }

    // MARK: - SF Symbol Icon

    public var icon: String {
        switch self {
        case .docker:         return "shippingbox.fill"
        case .kubernetes:     return "network"
        case .podman:         return "cylinder.split.1x2.fill"
        case .shell:          return "terminal.fill"
        case .ssh:            return "server.rack"
        case .httpCheck:      return "waveform.path.ecg"
        case .tunnel:         return "cloud.bolt.fill"
        case .processMonitor: return "cpu.fill"
        }
    }

    // MARK: - Brand Color

    public var color: Color {
        switch self {
        case .docker:         return Color(red: 0.00, green: 0.72, blue: 0.98)
        case .kubernetes:     return Color(red: 0.05, green: 0.55, blue: 0.98)
        case .podman:         return Color(red: 0.58, green: 0.20, blue: 0.75)
        case .shell:          return Color(red: 0.09, green: 0.50, blue: 0.20)
        case .ssh:            return Color(red: 0.28, green: 0.35, blue: 0.44)
        case .httpCheck:      return Color(red: 0.02, green: 0.84, blue: 0.63)
        case .tunnel:         return Color(red: 0.96, green: 0.48, blue: 0.08)
        case .processMonitor: return Color(red: 0.95, green: 0.22, blue: 0.35)
        }
    }

    // MARK: - Deterministic Stable ID

    public var stableID: UUID {
        .stable("provider.\(rawValue)")
    }

    // MARK: - Tooltip for [+] Action

    public var addTooltip: String {
        switch self {
        case .docker:         return "New Docker Service"
        case .kubernetes:     return "New Kube Forward"
        case .podman:         return "New Podman Service"
        case .shell:          return "New Shell Script"
        case .ssh:            return "New SSH Connection"
        case .httpCheck:      return "New Health Check"
        case .tunnel:         return "New Tunnel"
        case .processMonitor: return "New Process"
        }
    }
}
