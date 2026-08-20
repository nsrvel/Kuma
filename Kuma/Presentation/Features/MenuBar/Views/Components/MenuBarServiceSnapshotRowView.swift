import SwiftUI

/// A compact row representing a service snapshot inside the MenuBar Extra popup.
/// Shows status dot, service name, provider tag, and quick Start/Stop button.
public struct MenuBarServiceSnapshotRowView: View {
    public let snapshot: ServiceCardSnapshot
    public let isRunning: Bool
    public let onToggle: () -> Void

    @State private var isHovered: Bool = false

    public init(
        snapshot: ServiceCardSnapshot,
        isRunning: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.isRunning = isRunning
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Status Dot
            Circle()
                .fill(snapshot.isDisabled ? Color.secondary.opacity(0.3) : (isRunning ? Color.green : Color.secondary.opacity(0.4)))
                .frame(width: 6, height: 6)

            // Service & Provider Details
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.name)
                    .font(.system(size: 11.5, weight: isRunning ? .medium : .regular))
                    .foregroundStyle(snapshot.isDisabled ? .secondary : .primary)
                    .lineLimit(1)

                Text(snapshot.subtitle.isEmpty ? snapshot.providerCategory.sidebarLabel : snapshot.subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()


            if !snapshot.isDisabled {
                // Quick Toggle Button
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isRunning ? Color.red : Color.green)
                        .frame(width: 20, height: 20)
                        .background(
                            (isRunning ? Color.red : Color.green).opacity(isHovered ? 0.18 : 0.09),
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
                .help(isRunning ? "Stop \(snapshot.name)" : "Start \(snapshot.name)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
    }
}
