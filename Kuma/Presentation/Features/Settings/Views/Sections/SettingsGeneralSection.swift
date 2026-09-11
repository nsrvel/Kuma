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
                    description: "Open Kuma automatically at login."
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Auto-start Services",
                    value: $viewModel.autoResumeServices,
                    description: "Resume active services when Kuma launches."
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Confirm Before Quitting",
                    value: $viewModel.confirmBeforeQuit,
                    description: "Prompt before quitting when services are active."
                )

                if viewModel.confirmBeforeQuit && UserDefaults.standard.string(forKey: KumaSettingsKey.quitBehavior) != nil {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved Quit Preference")
                                .font(KumaFont.subheadline)
                            Text("Clear saved preference and prompt on quit.")
                                .font(KumaFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset") {
                            UserDefaults.standard.removeObject(forKey: KumaSettingsKey.quitBehavior)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}
