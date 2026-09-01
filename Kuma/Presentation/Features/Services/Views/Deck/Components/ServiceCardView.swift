import SwiftUI

public struct ServiceCardView: View, Equatable {
    public let snapshot: ServiceCardSnapshot
    public let runtime: ServiceRuntimeState
    public let isSelected: Bool

    // Direct ViewModel reference
    public let viewModel: ServicesDeckViewModel
    public let workspaceID: UUID

    public init(
        snapshot: ServiceCardSnapshot,
        runtime: ServiceRuntimeState = .idle,
        isSelected: Bool = false,
        viewModel: ServicesDeckViewModel,
        workspaceID: UUID
    ) {
        self.snapshot = snapshot
        self.runtime = runtime
        self.isSelected = isSelected
        self.viewModel = viewModel
        self.workspaceID = workspaceID
    }

    // MARK: - Extreme Limit: Equatable bypass for zero redundant body evaluation
    public static func == (lhs: ServiceCardView, rhs: ServiceCardView) -> Bool {
        lhs.snapshot == rhs.snapshot &&
        lhs.runtime == rhs.runtime &&
        lhs.isSelected == rhs.isSelected &&
        lhs.workspaceID == rhs.workspaceID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Provider Icon + Name/Target Subtitle + Native Toggle
            HStack(spacing: 12) {
                // Service Provider Icon with Star Overlay Badge
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                snapshot.isDisabled
                                ? LinearGradient(colors: [Color.secondary.opacity(0.18), Color.secondary.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : snapshot.providerCategory.gradient
                            )
                            .frame(width: 34, height: 34)
                            .shadow(color: Color.black.opacity(snapshot.isDisabled ? 0.0 : 0.16), radius: 2, y: 1)

                        Image(systemName: snapshot.providerCategory.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(snapshot.isDisabled ? Color.secondary : Color.white)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(snapshot.isDisabled ? .secondary : .primary)
                        .lineLimit(1)

                    Text(targetSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Micro-component: Isolated Toggle Switch
                CardToggleSwitch(
                    isDisabled: snapshot.isDisabled,
                    runtime: runtime,
                    onToggle: { viewModel.toggleService(id: snapshot.id) }
                )
            }

            // Footer Row: Static Ports OR Contextual Provider Badge + Live Status Observer
            HStack(spacing: 6) {
                if !snapshot.portDisplays.isEmpty {
                    PortChipsView(ports: snapshot.portDisplays, limit: 3)
                } else {
                    ServiceNonPortBadge(category: snapshot.providerCategory)
                }

                Spacer(minLength: 4)

                // Micro-Observer: Updates only this pill when status changes
                ServiceStatusObserver(state: runtime, isDisabled: snapshot.isDisabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KumaColors.surfaceBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2.0)
            }
        }
        .opacity(snapshot.isDisabled ? 0.65 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onTapGesture {
            viewModel.selectService(snapshot.id)
        }
        .contextMenu {
            ServiceActionContextMenu(
                snapshot: snapshot,
                runtime: runtime,
                onToggle: { viewModel.toggleService(id: snapshot.id) },
                onToggleStar: { viewModel.toggleStarred(id: snapshot.id, workspaceID: workspaceID) },
                onSelect: { viewModel.selectService(snapshot.id) }
            )
        }
    }

    private var targetSubtitle: String {
        if !snapshot.subtitle.isEmpty {
            return snapshot.subtitle
        }
        return snapshot.providerCategory.sidebarLabel
    }
}

/// Isolated micro-view for the toggle switch button to prevent full card re-evaluations
private struct CardToggleSwitch: View, Equatable {
    let isDisabled: Bool
    let runtime: ServiceRuntimeState
    let onToggle: () -> Void

    static func == (lhs: CardToggleSwitch, rhs: CardToggleSwitch) -> Bool {
        lhs.isDisabled == rhs.isDisabled &&
        lhs.runtime == rhs.runtime
    }

    var body: some View {
        if isDisabled {
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
}
