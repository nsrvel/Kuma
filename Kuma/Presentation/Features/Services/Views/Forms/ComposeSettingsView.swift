import SwiftUI

/// Shared compose YAML editor for Docker and Podman providers.
public struct ComposeSettingsView: View {
    public let engineTitle: String
    public let emptySummary: String
    public let editorPlaceholder: String
    public let composeFilePlaceholder: String
    @Binding public var yamlConfig: String
    @Binding public var composeFilePath: String
    public var isLocked: Bool
    public var onSave: () -> Void

    @State private var isExpanded: Bool = false
    @State private var sourceMode: KumaDualSourceMode = .chooseFile
    @State private var draftYAML: String = ""
    @State private var draftPath: String = ""

    public init(
        engineTitle: String,
        emptySummary: String,
        editorPlaceholder: String,
        composeFilePlaceholder: String = "~/path/to/docker-compose.yml",
        yamlConfig: Binding<String>,
        composeFilePath: Binding<String>,
        isLocked: Bool = false,
        onSave: @escaping () -> Void = {}
    ) {
        self.engineTitle = engineTitle
        self.emptySummary = emptySummary
        self.editorPlaceholder = editorPlaceholder
        self.composeFilePlaceholder = composeFilePlaceholder
        self._yamlConfig = yamlConfig
        self._composeFilePath = composeFilePath
        self.isLocked = isLocked
        self.onSave = onSave
    }

    public var body: some View {
        Group {
            if !isExpanded {
                collapsedRow
            } else {
                expandedPanel
            }
        }
        .onChange(of: isLocked) { _, locked in
            if locked && isExpanded { collapseEditor() }
        }
        .onDisappear { isExpanded = false }
        .onChange(of: draftPath) { _, newPath in
            guard isExpanded, sourceMode == .chooseFile else { return }
            applyFileSelection(newPath)
        }
    }

    private var collapsedRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compose File")
                    .font(KumaFont.body)
                Text(summaryText)
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Configure") { openEditor() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLocked)
        }
    }

    private var expandedPanel: some View {
        KumaFormInlinePanel(
            headerTitle: engineTitle,
            headerIcon: "doc.text.fill",
            closeAccessibilityLabel: "Close compose editor",
            primaryTitle: "Done",
            showsCommitFooter: sourceMode == .pasteYAML,
            onCancel: { cancelEditor() },
            onPrimary: { commitPasteAndCollapse() }
        ) {
            ComposeSettingsExpandedContent(
                sourceMode: $sourceMode,
                draftPath: $draftPath,
                draftYAML: $draftYAML,
                composeFilePlaceholder: composeFilePlaceholder,
                editorPlaceholder: editorPlaceholder
            )
        }
    }

    private var summaryText: String {
        let path = composeFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
            return "\((path as NSString).lastPathComponent) · \(KumaFileMetadata.truncatedParentPath(path: path))"
        }
        let trimmed = yamlConfig.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return emptySummary }
        let lineCount = trimmed.components(separatedBy: .newlines).count
        return "Paste YAML · \(lineCount) \(lineCount == 1 ? "line" : "lines")"
    }

    private func openEditor() {
        draftYAML = yamlConfig
        draftPath = composeFilePath
        sourceMode = inferredMode(path: composeFilePath, yaml: yamlConfig)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded = true }
    }

    private func applyFileSelection(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        composeFilePath = trimmed
        if !trimmed.isEmpty { yamlConfig = "" }
        onSave()
    }

    private func commitPasteAndCollapse() {
        yamlConfig = draftYAML
        composeFilePath = ""
        onSave()
        collapseEditor()
    }

    private func cancelEditor() {
        if sourceMode == .pasteYAML {
            draftYAML = yamlConfig
        } else {
            draftPath = composeFilePath
        }
        collapseEditor()
    }

    private func collapseEditor() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded = false }
    }

    private func inferredMode(path: String, yaml: String) -> KumaDualSourceMode {
        if !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .chooseFile }
        if !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .pasteYAML }
        return .chooseFile
    }
}
