import SwiftUI

public struct PodmanComposeSettingsView: View {
    @Binding public var yamlConfig: String
    public var isLocked: Bool
    public var onSave: () -> Void

    public init(
        yamlConfig: Binding<String>,
        isLocked: Bool = false,
        onSave: @escaping () -> Void = {}
    ) {
        self._yamlConfig = yamlConfig
        self.isLocked = isLocked
        self.onSave = onSave
    }

    public var body: some View {
        ComposeSettingsView(
            engineTitle: "Podman Compose (podman-compose.yml)",
            emptySummary: "No podman-compose.yml configured.",
            editorPlaceholder: "version: '3.8'\nservices:\n  app:\n    image: quay.io/podman/hello\n    ports:\n      - \"8080:8080\"",
            yamlConfig: $yamlConfig,
            isLocked: isLocked,
            onSave: onSave
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var yaml = "version: '3.8'\nservices:\n  api:\n    image: node:18-alpine"

        var body: some View {
            PodmanComposeSettingsView(yamlConfig: $yaml)
                .padding()
                .frame(width: 500)
        }
    }
    return PreviewWrapper()
}
