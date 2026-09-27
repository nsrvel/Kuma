import SwiftUI

public struct DockerComposeSettingsView: View {
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
            engineTitle: "Docker Compose (docker-compose.yml)",
            emptySummary: "No docker-compose.yml configured.",
            editorPlaceholder: "version: '3.8'\nservices:\n  web:\n    image: nginx:alpine\n    ports:\n      - \"80:80\"",
            yamlConfig: $yamlConfig,
            isLocked: isLocked,
            onSave: onSave
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var yaml = "version: '3.8'\nservices:\n  db:\n    image: postgres:15"

        var body: some View {
            DockerComposeSettingsView(yamlConfig: $yaml)
                .padding()
                .frame(width: 500)
        }
    }
    return PreviewWrapper()
}
