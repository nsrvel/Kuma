import SwiftUI

public struct ServiceCardView: View {
    public let snapshot: ServiceCardSnapshot
    public let runtime: ServiceRuntimeState
    public let isSelected: Bool

    public var onToggle: () -> Void
    public var onSelect: () -> Void

    public let onToggleStar: () -> Void

    public init(
        snapshot: ServiceCardSnapshot,
        runtime: ServiceRuntimeState = ServiceRuntimeState(),
        isSelected: Bool = false,
        onToggle: @escaping () -> Void = {},
        onToggleStar: @escaping () -> Void = {},
        onSelect: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.runtime = runtime
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onToggleStar = onToggleStar
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Provider Icon + Name/Target Subtitle + Native Toggle
            HStack(spacing: 12) {
                // Service Provider Icon with Star Overlay Badge
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                snapshot.isDisabled
                                ? Color.secondary.opacity(0.18).gradient
                                : snapshot.providerCategory.color.gradient
                            )
                            .frame(width: 34, height: 34)
                            .shadow(color: Color.black.opacity(snapshot.isDisabled ? 0.0 : 0.04), radius: 1, y: 0.5)

                        Image(systemName: snapshot.providerCategory.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(snapshot.isDisabled ? Color.secondary : .white)
                    }

                    if snapshot.isStarred {
                        ZStack {
                            Circle()
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .frame(width: 14, height: 14)

                            Image(systemName: "star.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.yellow)
                        }
                        .offset(x: 4, y: -4)
                        .shadow(color: Color.black.opacity(0.15), radius: 1, y: 0.5)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.26, dampingFraction: 0.65), value: snapshot.isStarred)

                // Name & Contextual Target Subtitle (Image/Namespace/Target)
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(snapshot.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(snapshot.isDisabled ? .secondary : .primary)
                        .lineLimit(1)

                    Text(targetSubtitle)
                        .font(.system(size: 11, design: isMonospacedTarget ? .monospaced : .default))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Native macOS Toggle Switch
                if snapshot.isDisabled {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                } else {
                    let isOnBinding = Binding<Bool>(
                        get: { runtime.status == .running || runtime.status == .starting },
                        set: { _ in onToggle() }
                    )
                    Toggle("", isOn: isOnBinding)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .disabled(runtime.isLoading || runtime.status == .starting || runtime.status == .stopping)
                }
            }

            // Footer Row: Static Ports OR Contextual Provider Badge + Live Status Observer
            HStack(spacing: 6) {
                if !snapshot.portDisplays.isEmpty {
                    PortChipsView(ports: snapshot.portDisplays, limit: 3)
                } else {
                    // Contextual Badge for services without port bindings
                    nonPortBadge
                }

                Spacer(minLength: 4)

                // Micro-Observer: Updates only this pill when status changes
                ServiceStatusObserver(state: runtime, isDisabled: snapshot.isDisabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Adaptive translucent surface that harmonizes with window material
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(snapshot.isDisabled ? 0.35 : 0.40))
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(snapshot.isDisabled ? 0.35 : 0.55),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        }
        .opacity(snapshot.isDisabled ? 0.75 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            ServiceActionContextMenu(
                snapshot: snapshot,
                runtime: runtime,
                onToggle: onToggle,
                onToggleStar: onToggleStar,
                onSelect: onSelect
            )
        }
    }

    // MARK: - Contextual Non-Port Badge

    @ViewBuilder
    private var nonPortBadge: some View {
        let (icon, label) = nonPortMetadata

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

    private var nonPortMetadata: (icon: String, label: String) {
        switch snapshot.providerCategory {
        case .httpCheck:
            return ("waveform.path.ecg", "Health Check")
        case .shell:
            return ("terminal", "Shell Script")
        case .processMonitor:
            return ("cpu", "Process")
        case .docker, .podman:
            return ("arrow.triangle.2.circlepath", "Worker")
        case .ssh:
            return ("server.rack", "SSH Session")
        case .tunnel:
            return ("cloud", "Tunnel")
        case .kubernetes:
            return ("network", "Cluster Pod")
        }
    }

    // MARK: - Contextual Subtitle

    private var targetSubtitle: String {
        if !snapshot.subtitle.isEmpty {
            return snapshot.subtitle
        }
        return snapshot.providerCategory.sidebarLabel
    }

    private var isMonospacedTarget: Bool {
        switch snapshot.providerCategory {
        case .docker, .podman, .kubernetes, .shell, .ssh:
            return !snapshot.subtitle.isEmpty
        default:
            return false
        }
    }
}
