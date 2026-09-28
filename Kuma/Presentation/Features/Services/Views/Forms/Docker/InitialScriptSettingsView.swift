import SwiftUI

// MARK: - InitialScriptSettingsView

/// Pre-startup shell script: file on disk (card) or inline snippet.
public struct InitialScriptSettingsView: View {
    @Binding public var initialScript: String
    @Binding public var initialScriptPath: String
    public var isLocked: Bool
    public var onSave: () -> Void

    @State private var isExpanded: Bool = false
    @State private var sourceMode: KumaDualSourceMode = .chooseFile
    @State private var draftScript: String = ""
    @State private var draftPath: String = ""

    public init(
        initialScript: Binding<String>,
        initialScriptPath: Binding<String>,
        isLocked: Bool = false,
        onSave: @escaping () -> Void = {}
    ) {
        self._initialScript = initialScript
        self._initialScriptPath = initialScriptPath
        self.isLocked = isLocked
        self.onSave = onSave
    }

    public var body: some View {
        Group {
            if !isExpanded { collapsedContent } else { expandedPanel }
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

    @ViewBuilder
    private var collapsedContent: some View {
        let path = initialScriptPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
            VStack(alignment: .leading, spacing: KumaSpacing.sm) {
                Text("Startup Script")
                    .font(KumaFont.body)
                KumaAttachedFileCard(
                    path: path,
                    systemImage: "terminal.fill",
                    isLocked: isLocked,
                    onChange: { openEditor(preferInline: false) },
                    onRemove: {
                        initialScriptPath = ""
                        onSave()
                    },
                    onRevealInFinder: { KumaScriptFileSupport.revealInFinder(path: path) }
                )
            }
        } else {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Startup Script")
                        .font(KumaFont.body)
                    Text(summaryText)
                        .font(KumaFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Configure") {
                    openEditor(preferInline: !initialScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLocked)
            }
        }
    }

    private var expandedPanel: some View {
        KumaFormInlinePanel(
            headerTitle: "Startup Script (sh / bash)",
            headerIcon: "terminal.fill",
            closeAccessibilityLabel: "Close startup script editor",
            showsCommitFooter: sourceMode == .pasteYAML,
            onCancel: { cancelEditor() },
            onPrimary: { commitPasteAndCollapse() }
        ) {
            InitialScriptSettingsExpandedContent(
                sourceMode: $sourceMode,
                draftPath: $draftPath,
                draftScript: $draftScript
            )
        }
    }

    private var summaryText: String {
        let trimmed = initialScript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "No startup script configured." }
        let lineCount = trimmed.components(separatedBy: .newlines).count
        return "Paste Script · \(lineCount) \(lineCount == 1 ? "line" : "lines")"
    }

    private func openEditor(preferInline: Bool) {
        draftScript = initialScript
        draftPath = initialScriptPath
        sourceMode = inferredMode(path: initialScriptPath, script: initialScript, preferInline: preferInline)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded = true }
    }

    private func applyFileSelection(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        initialScriptPath = trimmed
        if !trimmed.isEmpty { initialScript = "" }
        onSave()
    }

    private func commitPasteAndCollapse() {
        initialScript = draftScript
        initialScriptPath = ""
        onSave()
        collapseEditor()
    }

    private func cancelEditor() {
        if sourceMode == .pasteYAML {
            draftScript = initialScript
        } else {
            draftPath = initialScriptPath
        }
        collapseEditor()
    }

    private func collapseEditor() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded = false }
    }

    private func inferredMode(path: String, script: String, preferInline: Bool) -> KumaDualSourceMode {
        if !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .chooseFile }
        if !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .pasteYAML }
        return preferInline ? .pasteYAML : .chooseFile
    }
}
