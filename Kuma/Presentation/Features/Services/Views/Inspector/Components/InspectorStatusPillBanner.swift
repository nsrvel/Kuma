import SwiftUI

public struct InspectorStatusPillBanner: View {
    /// Original pill chrome; stopped-state tint for every status (no per-state green/amber/red).
    private static let bannerTint = KumaStatus.indicatorColor(for: .stopped)

    public let title: String
    public let subtitle: String
    public var onViewLogs: (() -> Void)? = nil

    public init(
        title: String,
        subtitle: String,
        onViewLogs: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onViewLogs = onViewLogs
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let onViewLogs {
                liveLogsButton(action: onViewLogs)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Self.bannerTint.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Self.bannerTint.opacity(0.25), lineWidth: 0.8)
        }
    }

    private func liveLogsButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 9))
                Text("Live Logs")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(KumaUIID.inspectorLiveLogsButton)
        .help("Open real-time console logs")
    }
}
