import SwiftUI

public struct SettingsLogsSection: View {
    @Bindable var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        KumaFormSection(
            icon: "doc.text.fill",
            title: "Logs"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                KumaRowPickerField(
                    label: "Log Buffer Limit",
                    description: "Maximum log lines retained in memory per service.",
                    options: LogRetentionLimit.allCases,
                    selection: $viewModel.logRetentionLimit,
                    titleResolver: { $0.title }
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Clear Logs on Restart",
                    value: $viewModel.clearLogsOnSwitch,
                    description: "Flush console output when a service restarts."
                )
            }
        }
    }
}
