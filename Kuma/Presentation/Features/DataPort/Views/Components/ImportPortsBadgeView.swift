import SwiftUI

public struct ImportPortsBadgeView: View {
    public let portMappings: [DataPortService.ExportPortMapping]
    public let maxVisible: Int

    public init(portMappings: [DataPortService.ExportPortMapping], maxVisible: Int = 2) {
        self.portMappings = portMappings
        self.maxVisible = maxVisible
    }

    public var body: some View {
        if portMappings.isEmpty {
            Text("—")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 4) {
                ForEach(portMappings.prefix(maxVisible), id: \.id) { port in
                    Text(portText(for: port))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                        .help("Host :\(port.localPort) ➔ Container :\(port.remotePort)")
                }

                if portMappings.count > maxVisible {
                    Text("+\(portMappings.count - maxVisible)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .help(remainingPortsTooltip)
                }
            }
        }
    }

    private func portText(for port: DataPortService.ExportPortMapping) -> String {
        if port.localPort == port.remotePort {
            return ":\(port.localPort)"
        }
        return "\(port.localPort):\(port.remotePort)"
    }

    private var remainingPortsTooltip: String {
        portMappings.dropFirst(maxVisible)
            .map { portText(for: $0) }
            .joined(separator: ", ")
    }
}
