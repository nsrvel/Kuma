import SwiftUI

public struct SettingsLogsSection: View {
    @Bindable var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        KumaFormSection(
            icon: "doc.text.fill",
            title: "Logs & Buffer"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                KumaRowPickerField(
                    label: "Max Log Buffer in Memory",
                    description: "Maximum memory buffer kept per running service inspector.",
                    options: LogRetentionLimit.allCases,
                    selection: $viewModel.logRetentionLimit,
                    titleResolver: { $0.title }
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Clear Buffer on Service Restart",
                    value: $viewModel.clearLogsOnSwitch,
                    description: "Flush previous console output when triggering a service restart."
                )
            }
        }
    }
}
