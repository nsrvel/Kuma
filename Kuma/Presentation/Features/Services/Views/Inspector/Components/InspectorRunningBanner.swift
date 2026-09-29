import SwiftUI

/// Contextual status banner in Inspector with optional Live Logs CTA.
public struct InspectorRunningBanner: View {
    public let runtime: ServiceRuntimeState
    public let isDisabled: Bool
    public var crashDetail: String?
    public let onViewLogs: () -> Void

    public init(
        runtime: ServiceRuntimeState,
        isDisabled: Bool = false,
        crashDetail: String? = nil,
        onViewLogs: @escaping () -> Void
    ) {
        self.runtime = runtime
        self.isDisabled = isDisabled
        self.crashDetail = crashDetail
        self.onViewLogs = onViewLogs
    }

    private var isTransitional: Bool {
        runtime.isLoading || runtime.status == .starting || runtime.status == .stopping
    }

    public var body: some View {
        if isDisabled {
            InspectorStatusPillBanner(
                title: "Disabled",
                subtitle: "Turn on in Options to run or edit.",
                tone: KumaStatus.disabledIndicator,
                washStrength: 0
            )
        } else {
            switch runtime.status {
            case .running:
                statusBanner(
                    title: "Running",
                    subtitle: "Settings are read-only while active.",
                    status: .running,
                    onViewLogs: onViewLogs
                )
            case .starting:
                statusBanner(
                    title: "Starting…",
                    subtitle: "Bringing the runner online.",
                    status: .starting,
                    onViewLogs: onViewLogs
                )
            case .stopping:
                statusBanner(
                    title: "Stopping…",
                    subtitle: "Waiting for a clean shutdown.",
                    status: .stopping
                )
            case .crashed:
                let detail = crashDetail?
                    .split(whereSeparator: \.isNewline)
                    .first
                    .map(String.init)
                statusBanner(
                    title: "Crashed",
                    subtitle: detail ?? "Open Live Logs for details.",
                    status: .crashed,
                    washStrength: 0.12,
                    onViewLogs: onViewLogs
                )
            case .stopped:
                statusBanner(
                    title: "Stopped",
                    subtitle: "You can edit all settings.",
                    status: .stopped,
                    onViewLogs: onViewLogs
                )
            }
        }
    }

    private func statusBanner(
        title: String,
        subtitle: String,
        status: ServiceState,
        washStrength: Double = 0.10,
        onViewLogs: (() -> Void)? = nil
    ) -> InspectorStatusPillBanner {
        InspectorStatusPillBanner(
            title: title,
            subtitle: subtitle,
            tone: KumaStatus.indicatorColor(for: status),
            showsOrbit: isTransitional,
            showsGlow: status == .running && !isTransitional,
            washStrength: washStrength,
            onViewLogs: onViewLogs
        )
    }
}
