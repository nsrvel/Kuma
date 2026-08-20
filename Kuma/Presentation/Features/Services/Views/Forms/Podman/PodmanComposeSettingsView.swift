import SwiftUI

// MARK: - PodmanComposeSettingsView

/// Podman Compose YAML configuration editor with privacy masking and default templates.
public struct PodmanComposeSettingsView: View {
    @Binding public var yamlConfig: String

    public init(yamlConfig: Binding<String>) {
        self._yamlConfig = yamlConfig
    }

    public var body: some View {
        KumaCollapsibleCodeField(
            label: "Compose File (podman-compose.yml)",
            value: $yamlConfig,
            placeholder: "version: '3.8'\nservices:\n  app:\n    image: quay.io/podman/hello\n    ports:\n      - \"8080:8080\"",
            height: 150,
            configureActionTitle: "Configure Compose YAML",
            revealActionTitle: "Reveal Compose YAML",
            iconName: "shippingbox.fill"
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var yaml = "version: '3.8'\nservices:\n  api:\n    image: node:18-alpine\n    ports:\n      - \"3000:3000\""

        var body: some View {
            KumaFormSection(
                icon: "shippingbox.fill",
                title: "Podman Compose"
            ) {
                PodmanComposeSettingsView(yamlConfig: $yaml)
            }
            .padding()
            .frame(width: 500)
            .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}
