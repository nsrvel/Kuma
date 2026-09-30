import SwiftUI

public struct InspectorComposeFormSection: View {
    @Binding public var provider: Provider
    public let isLocked: Bool
    public let isPodman: Bool
    public let onFieldChanged: () -> Void

    public var body: some View {
        KumaFormSection(icon: "shippingbox.fill", title: "Configuration") {
            VStack(alignment: .leading, spacing: 14) {
                if isPodman {
                    PodmanComposeSettingsView(
                        yamlConfig: Binding(
                            get: { provider.yamlConfig ?? "" },
                            set: { provider.yamlConfig = $0; onFieldChanged() }
                        ),
                        isLocked: isLocked,
                        onSave: onFieldChanged
                    )
                } else {
                    DockerComposeSettingsView(
                        yamlConfig: Binding(
                            get: { provider.yamlConfig ?? "" },
                            set: { provider.yamlConfig = $0; onFieldChanged() }
                        ),
                        isLocked: isLocked,
                        onSave: onFieldChanged
                    )
                }

                KumaDivider(opacity: 0.06, verticalPadding: 2)

                InitialScriptSettingsView(
                    initialScript: Binding(
                        get: { provider.initialScript ?? "" },
                        set: { provider.initialScript = $0.isEmpty ? nil : $0; onFieldChanged() }
                    ),
                    isLocked: isLocked,
                    onSave: onFieldChanged
                )
            }
            .disabled(isLocked)
        }
    }
}
