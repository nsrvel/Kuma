import SwiftUI

public struct SettingsGeneralSection: View {
    @Bindable var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        KumaFormSection(
            icon: "gearshape.fill",
            title: "General"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                KumaToggleField(
                    label: "Launch at Login",
                    value: $viewModel.launchAtLogin,
                    description: "Automatically open Kuma when you log into your Mac."
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Auto-start Services",
                    value: $viewModel.autoResumeServices,
                    description: "Automatically resume services that were active when Kuma was last quit."
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Confirm Before Quitting",
                    value: $viewModel.confirmBeforeQuit,
                    description: "Show a confirmation prompt when quitting Kuma while services are running."
                )

                if viewModel.confirmBeforeQuit && UserDefaults.standard.string(forKey: KumaSettingsKey.quitBehavior) != nil {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remembered Quit Choice")
                                .font(KumaFont.subheadline)
                            Text("Reset saved quit behavior preference to prompt every time.")
                                .font(KumaFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset Choice") {
                            UserDefaults.standard.removeObject(forKey: KumaSettingsKey.quitBehavior)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}
