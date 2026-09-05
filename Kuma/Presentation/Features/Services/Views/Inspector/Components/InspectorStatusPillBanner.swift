import SwiftUI

public struct InspectorStatusPillBanner: View {
    public let icon: String
    public let title: String
    public let subtitle: String
    public let tintColor: Color
    public var isLoading: Bool = false
    public var onViewLogs: (() -> Void)? = nil

    public init(
        icon: String,
        title: String,
        subtitle: String,
        tintColor: Color,
        isLoading: Bool = false,
        onViewLogs: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tintColor = tintColor
        self.isLoading = isLoading
        self.onViewLogs = onViewLogs
    }

    public var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                KumaActivityIndicator(size: 14, color: tintColor, lineWidth: 1.5)
            } else {
                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.15))
                        .frame(width: 24, height: 24)

                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tintColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer(minLength: 6)

            if let onViewLogs {
                Button {
                    onViewLogs()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 9))
                        Text("Live Logs")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
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
                .help("Open real-time console logs")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tintColor.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tintColor.opacity(0.25), lineWidth: 0.8)
        }
    }
}
