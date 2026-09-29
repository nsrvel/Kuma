import SwiftUI
import UniformTypeIdentifiers

/// Shared compose YAML editor for Docker and Podman providers.
public struct ComposeSettingsView: View {
    public let filePrompt: String
    public let editorPlaceholder: String
    @Binding public var yamlConfig: String
    @Binding public var composeFilePath: String
    public var isLocked: Bool
    public var onSave: () -> Void

    @State private var sourceMode: KumaDualSourceMode = .chooseFile

    public init(
        filePrompt: String,
        editorPlaceholder: String,
        yamlConfig: Binding<String>,
        composeFilePath: Binding<String>,
        isLocked: Bool = false,
        onSave: @escaping () -> Void = {}
    ) {
        self.filePrompt = filePrompt
        self.editorPlaceholder = editorPlaceholder
        self._yamlConfig = yamlConfig
        self._composeFilePath = composeFilePath
        self.isLocked = isLocked
        self.onSave = onSave
    }

    public var body: some View {
        KumaSourceField(
            label: "Compose File",
            mode: $sourceMode,
            path: pathBinding,
            text: yamlBinding,
            filePrompt: filePrompt,
            editorPlaceholder: editorPlaceholder,
            allowedContentTypes: ComposeFileTypes.allowed,
            isLocked: isLocked
        )
        .onAppear { syncModeFromBindings() }
    }

    private var pathBinding: Binding<String> {
        Binding(
            get: { composeFilePath },
            set: { newPath in
                let trimmed = newPath.trimmingCharacters(in: .whitespacesAndNewlines)
                composeFilePath = trimmed
                if !trimmed.isEmpty, !yamlConfig.isEmpty {
                    yamlConfig = ""
                }
                onSave()
            }
        )
    }

    private var yamlBinding: Binding<String> {
        Binding(
            get: { yamlConfig },
            set: { newYAML in
                yamlConfig = newYAML
                if !newYAML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !composeFilePath.isEmpty {
                    composeFilePath = ""
                }
                onSave()
            }
        )
    }

    private func syncModeFromBindings() {
        sourceMode = KumaDualSourceMode.inferred(
            path: composeFilePath,
            text: yamlConfig,
            fallback: .chooseFile
        )
    }
}

public enum ComposeFileTypes {
    public static let allowed: [UTType] = {
        var types: [UTType] = []
        if let yml = UTType(filenameExtension: "yml") { types.append(yml) }
        if let yaml = UTType(filenameExtension: "yaml") { types.append(yaml) }
        types.append(.plainText)
        return types
    }()
}
