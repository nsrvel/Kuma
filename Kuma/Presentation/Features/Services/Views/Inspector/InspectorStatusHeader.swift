import SwiftUI

/// Fixed header zone for the Service Inspector.
/// Displays provider identity, service status, toggle, and a thin action toolbar strip.
public struct InspectorStatusHeader: View {
    public let snapshot: ServiceCardSnapshot
    public let runtime: ServiceRuntimeState
    public let onToggle: () -> Void
    public let onToggleStar: () -> Void
    public let onEdit: () -> Void

    public init(
        snapshot: ServiceCardSnapshot,
        runtime: ServiceRuntimeState,
        onToggle: @escaping () -> Void,
        onToggleStar: @escaping () -> Void,
        onEdit: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.runtime = runtime
        self.onToggle = onToggle
        self.onToggleStar = onToggleStar
        self.onEdit = onEdit
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: Identity Row
            HStack(spacing: 10) {
                // Provider gradient icon (matches card style)
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(snapshot.isDisabled
                              ? LinearGradient(colors: [.secondary.opacity(0.18), .secondary.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
                              : snapshot.providerCategory.gradient)
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(snapshot.isDisabled ? 0 : 0.14), radius: 2, y: 1)

                    Image(systemName: snapshot.providerCategory.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(snapshot.isDisabled ? Color.secondary : Color.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(snapshot.isDisabled ? .secondary : .primary)

                    HStack(spacing: 6) {
                        Text(snapshot.providerCategory.sidebarLabel)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(snapshot.providerCategory.color.opacity(0.9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(snapshot.providerCategory.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 3.5, style: .continuous))

                        ServiceStatusObserver(state: runtime, isDisabled: snapshot.isDisabled)
                    }
                }

                Spacer(minLength: 8)

                // Native toggle switch
                if snapshot.isDisabled {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                } else {
                    Toggle("", isOn: Binding<Bool>(
                        get: { runtime.status == .running || runtime.status == .starting },
                        set: { _ in onToggle() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .disabled(runtime.isLoading || runtime.status == .starting || runtime.status == .stopping)
                }
            }
            .padding(.horizontal, KumaSpacing.lg)
            .padding(.vertical, KumaSpacing.md)

            Divider().padding(.horizontal, KumaSpacing.lg)

            // MARK: Action Toolbar Strip (thin, borderless icons)
            HStack(spacing: 0) {
                // Start / Stop
                actionButton(
                    icon: runtime.status.isOperational ? "stop.fill" : "play.fill",
                    label: runtime.status.isOperational ? "Stop" : "Start",
                    tint: runtime.status.isOperational ? .red : .accentColor,
                    disabled: snapshot.isDisabled || runtime.isLoading
                ) { onToggle() }

                // Edit
                actionButton(icon: "pencil", label: "Edit") { onEdit() }

                // Star
                actionButton(
                    icon: snapshot.isStarred ? "star.fill" : "star",
                    label: snapshot.isStarred ? "Unstar" : "Star",
                    tint: snapshot.isStarred ? .yellow : nil
                ) { onToggleStar() }

                Spacer()

                // Overflow Menu
                Menu {
                    ServiceActionContextMenu(
                        snapshot: snapshot,
                        runtime: runtime,
                        onToggle: onToggle,
                        onToggleStar: onToggleStar,
                        onSelect: {}
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
                .help("More actions")
            }
            .padding(.horizontal, KumaSpacing.md)
            .padding(.vertical, KumaSpacing.xs)
        }
    }

    // MARK: - Borderless Action Button

    @ViewBuilder
    private func actionButton(
        icon: String,
        label: String,
        tint: Color? = nil,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint ?? .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(label)
    }
}
