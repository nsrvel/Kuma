import SwiftUI

/// Fixed header zone for the Service Inspector.
/// Displays provider identity, service status, toggle, and a thin action toolbar strip.
public struct InspectorStatusHeader: View {
    public let snapshot: ServiceCardSnapshot
    public let runtime: ServiceRuntimeState
    public let isEditMode: Bool
    public let hasChanges: Bool
    public let isSaving: Bool
    public let onToggle: () -> Void
    public let onToggleStar: () -> Void
    public let onBackToOverview: () -> Void
    public let onSave: () -> Void
    public let onCancel: () -> Void

    @State private var isStarHovered: Bool = false

    public init(
        snapshot: ServiceCardSnapshot,
        runtime: ServiceRuntimeState,
        isEditMode: Bool = false,
        hasChanges: Bool = false,
        isSaving: Bool = false,
        onToggle: @escaping () -> Void,
        onToggleStar: @escaping () -> Void = {},
        onBackToOverview: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.runtime = runtime
        self.isEditMode = isEditMode
        self.hasChanges = hasChanges
        self.isSaving = isSaving
        self.onToggle = onToggle
        self.onToggleStar = onToggleStar
        self.onBackToOverview = onBackToOverview
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: Identity Row
            HStack(spacing: 10) {
                if isEditMode {
                    Button {
                        onBackToOverview()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Back to Overview")
                } else {
                    // Provider gradient icon with Star Overlay Badge (matches card style)
                    ZStack(alignment: .topTrailing) {
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

                        if snapshot.isStarred {
                            ZStack {
                                Circle()
                                    .fill(Color(nsColor: .windowBackgroundColor))
                                    .frame(width: 13, height: 13)

                                Image(systemName: "star.fill")
                                    .font(.system(size: 7.5, weight: .bold))
                                    .foregroundStyle(Color.yellow)
                            }
                            .offset(x: 3.5, y: -3.5)
                            .shadow(color: Color.black.opacity(0.15), radius: 1, y: 0.5)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isEditMode ? "Edit Configuration" : snapshot.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(snapshot.isDisabled ? .secondary : .primary)

                    if isEditMode {
                        Text(snapshot.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(snapshot.providerCategory.sidebarLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }





                Spacer(minLength: 8)

                if hasChanges {
                    // Dynamic Save & Cancel Buttons when modifications are made
                    HStack(spacing: 6) {
                        Button("Cancel") {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isSaving)

                        Button {
                            onSave()
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Text("Save")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isSaving)
                    }
                    .padding(.trailing, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if isEditMode {
                    // Clean empty trailing side when no changes in edit mode
                    EmptyView()
                } else if snapshot.isDisabled {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 8)
                } else {
                    // Native macOS Rounded Tinted Action Button (Pure Text: "Start" / "Stop")
                    let isRunning = runtime.status.isOperational
                    let tintColor: Color = isRunning ? .red : .green

                    Button {
                        onToggle()
                    } label: {
                        HStack(spacing: 5) {
                            if runtime.isLoading || runtime.status == .starting || runtime.status == .stopping {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                            Text(isRunning ? "Stop" : "Start")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundStyle(tintColor)
                        .frame(minWidth: 56)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6.5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(tintColor.opacity(0.13))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(tintColor.opacity(0.35), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(runtime.isLoading || runtime.status == .starting || runtime.status == .stopping)
                    .padding(.trailing, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: hasChanges)


            .padding(.leading, KumaSpacing.lg)
            .padding(.trailing, KumaSpacing.lg)
            .padding(.vertical, KumaSpacing.md)
        }
    }
}
