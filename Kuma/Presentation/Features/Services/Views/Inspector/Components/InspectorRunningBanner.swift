import SwiftUI

/// Contextual notification banner shown in Inspector indicating current service status.
/// Always visible (static banner) regardless of whether the service is running, starting,
/// stopping, crashed, or stopped, providing a consistent layout with CTA to Live Logs.
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
                icon: "lock.slash.fill",
                title: "Service Disabled",
                subtitle: "Enable in Options below to configure or run",
                tintColor: .secondary
            )
        } else {
            switch runtime.status {
            case .running:
                InspectorStatusPillBanner(
                    icon: "lock.fill",
                    title: "Running — Settings Locked",
                    subtitle: "Stop the service to modify configuration",
                    tintColor: .green,
                    onViewLogs: onViewLogs
                )
            case .starting:
                InspectorStatusPillBanner(
                    icon: "gearshape.2.fill",
                    title: "Starting Process…",
                    subtitle: "Allocating ports and initializing runner",
                    tintColor: .yellow,
                    isLoading: true,
                    onViewLogs: onViewLogs
                )
            case .stopping:
                InspectorStatusPillBanner(
                    icon: "stop.fill",
                    title: "Stopping Service…",
                    subtitle: "Terminating subprocesses cleanly",
                    tintColor: .orange,
                    isLoading: true
                )
            case .crashed:
                InspectorStatusPillBanner(
                    icon: "exclamationmark.triangle.fill",
                    title: "Process Exited Unexpectedly",
                    subtitle: "Check terminal output for error details",
                    tintColor: .red,
                    onViewLogs: onViewLogs
                )
            case .stopped:
                InspectorStatusPillBanner(
                    icon: "stop.circle.fill",
                    title: "Ready to Start",
                    subtitle: "All configurations are unlocked and ready for execution",
                    tintColor: .secondary,
                    onViewLogs: onViewLogs
                )
            }
        }
    }
}
