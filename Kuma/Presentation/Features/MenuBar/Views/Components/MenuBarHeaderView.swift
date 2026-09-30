import SwiftUI

/// Top header inside Kuma MenuBar popover.
/// Shows current active workspace identity and overall operational status.
public struct MenuBarHeaderView: View {
    public let workspaceName: String
    public let activeCount: Int
    public let totalCount: Int
    public let onOpenMainWindow: () -> Void

    public init(
        workspaceName: String,
        activeCount: Int,
        totalCount: Int,
        onOpenMainWindow: @escaping () -> Void
    ) {
        self.workspaceName = workspaceName
        self.activeCount = activeCount
        self.totalCount = totalCount
        self.onOpenMainWindow = onOpenMainWindow
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Workspace Indicator Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 24, height: 24)

                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(workspaceName.isEmpty ? "Default Workspace" : workspaceName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(activeCount) of \(totalCount) running")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onOpenMainWindow()
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Kuma Main Window")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
