import SwiftUI

/// Native macOS fixed header zone for the Service Inspector.
/// Displays service identity, provider type, live status observer, and start/stop button.
public struct InspectorStatusHeader: View {
    public let service: Service
    public let provider: Provider?
    public let runtime: ServiceRuntimeState
    public var isViewingLogs: Bool = false
    public let onToggle: () -> Void
    public let onToggleStar: () -> Void
    public var onBack: () -> Void = {}

    public init(
        service: Service,
        provider: Provider?,
        runtime: ServiceRuntimeState,
        isViewingLogs: Bool = false,
        onToggle: @escaping () -> Void,
        onToggleStar: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        self.service = service
        self.provider = provider
        self.runtime = runtime
        self.isViewingLogs = isViewingLogs
        self.onToggle = onToggle
        self.onToggleStar = onToggleStar
        self.onBack = onBack
    }

    private var category: ProviderCategory {
        provider?.type ?? .docker
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: Identity Row
            HStack(spacing: 10) {
                if isViewingLogs {
                    // Back Button replacing provider icon (matching port chip tile styling)
                    Button {
                        onBack()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
                                }

                            Image(systemName: "chevron.left")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Back to Configuration")
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    // Provider gradient icon with Star Overlay Badge
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(service.isDisabled
                                      ? LinearGradient(colors: [.secondary.opacity(0.18), .secondary.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                      : category.gradient)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(service.isDisabled ? 0 : 0.14), radius: 2, y: 1)

                            ProviderBrandIcon(category: category, tunnelType: provider?.tunnelType, size: 16)
                                .foregroundStyle(service.isDisabled ? Color.secondary : Color.white)
                        }

                        if service.isStarred {
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
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(service.isDisabled ? .secondary : .primary)

                    Text(category.sidebarLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if service.isDisabled {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 8)
                } else if isViewingLogs {
                    // Header Log Controls: Copy & Clear
                    HStack(spacing: 6) {
                        Button {
                            copyLogs()
                        } label: {
                            HStack(spacing: 3.5) {
                                Image(systemName: copiedRecently ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10))
                                Text(copiedRecently ? "Copied" : "Copy")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4.5)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Copy logs to clipboard")

                        Button {
                            LogAggregator.shared.clear()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4.5)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Clear logs")
                    }
                    .padding(.trailing, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // Native macOS Rounded Tinted Action Button (Pure Text: "Start" / "Stop")
                    let isRunning = runtime.status.isOperational
                    let tintColor: Color = isRunning ? .red : .green

                    Button {
                        onToggle()
                    } label: {
                        HStack(spacing: 5) {
                            if runtime.isLoading || runtime.status == .starting || runtime.status == .stopping {
                                KumaActivityIndicator(size: 11, color: tintColor, lineWidth: 1.5)
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
        }
        .padding(.horizontal, KumaSpacing.lg)
        .padding(.vertical, KumaSpacing.md)
    }

    @State private var copiedRecently: Bool = false

    private func copyLogs() {
        let entries = LogAggregator.shared.entries.filter { $0.serviceID == service.id }
        let content = entries.map { "[\($0.timestamp)] [\($0.level)] \($0.message)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)

        withAnimation {
            copiedRecently = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                copiedRecently = false
            }
        }
    }
}


