import SwiftUI

/// Contextual status banner in Inspector with optional Live Logs CTA.
public struct InspectorRunningBanner: View {
    public let runtime: ServiceRuntimeState
    public let isDisabled: Bool
    public let onViewLogs: () -> Void

    public init(
        runtime: ServiceRuntimeState,
        isDisabled: Bool = false,
        onViewLogs: @escaping () -> Void
    ) {
        self.runtime = runtime
        self.isDisabled = isDisabled
        self.onViewLogs = onViewLogs
    }

    public var body: some View {
        if isDisabled {
            InspectorStatusPillBanner(
                title: "Disabled",
                subtitle: "Turn on in Options to run or edit."
            )
        } else {
            switch runtime.status {
            case .running:
                InspectorStatusPillBanner(
                    title: "Running",
                    subtitle: "Settings are read-only while active.",
                    onViewLogs: onViewLogs
                )
            case .starting:
                InspectorStatusPillBanner(
                    title: "Starting…",
                    subtitle: "Bringing the runner online.",
                    onViewLogs: onViewLogs
                )
            case .stopping:
                InspectorStatusPillBanner(
                    title: "Stopping…",
                    subtitle: "Waiting for a clean shutdown."
                )
            case .crashed:
                InspectorStatusPillBanner(
                    title: "Crashed",
                    subtitle: "Open Live Logs for details.",
                    onViewLogs: onViewLogs
                )
            case .stopped:
                InspectorStatusPillBanner(
                    title: "Stopped",
                    subtitle: "You can edit all settings.",
                    onViewLogs: onViewLogs
                )
            }
        }
    }
}
