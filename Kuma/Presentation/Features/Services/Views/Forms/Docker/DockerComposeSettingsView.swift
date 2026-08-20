import SwiftUI

// MARK: - DockerComposeSettingsView

/// Docker Compose YAML configuration editor with privacy masking and default templates.
public struct DockerComposeSettingsView: View {
    @Binding public var yamlConfig: String

    public init(yamlConfig: Binding<String>) {
        self._yamlConfig = yamlConfig
    }

    public var body: some View {
        KumaTextArea(
            label: "Compose File (docker-compose.yml)",
            value: $yamlConfig,
            placeholder: "version: '3.8'\nservices:\n  web:\n    image: nginx:alpine\n    ports:\n      - \"80:80\"",
            minHeight: 140,
            isMonospaced: true
        )
    }
}


#Preview {
    struct PreviewWrapper: View {
        @State private var yaml = "version: '3.8'\nservices:\n  db:\n    image: postgres:15\n    environment:\n      POSTGRES_PASSWORD: secretpassword"

        var body: some View {
            KumaFormSection(
                icon: "shippingbox.fill",
                title: "Docker Compose"
            ) {
                DockerComposeSettingsView(yamlConfig: $yaml)
            }
            .padding()
            .frame(width: 500)
            .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}
