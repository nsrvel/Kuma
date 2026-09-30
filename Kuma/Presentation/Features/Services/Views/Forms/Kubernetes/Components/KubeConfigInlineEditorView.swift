import AppKit
import SwiftUI

public struct KubeConfigInlineEditorView: View {
    @Bindable var viewModel: KubeConfigViewModel
    let onDismiss: () -> Void
    let onSaveSuccess: () -> Void

    private var saveDisabled: Bool {
        viewModel.newKubeConfigName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.newKubeConfigContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        viewModel: KubeConfigViewModel,
        onDismiss: @escaping () -> Void,
        onSaveSuccess: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onSaveSuccess = onSaveSuccess
    }

    public var body: some View {
        KumaFormInlinePanel(
            headerTitle: viewModel.editingKubeConfigID == nil ? "New Kube Config" : "Edit Kube Config",
            headerIcon: "doc.text.fill",
            closeAccessibilityLabel: "Close kube config editor",
            primaryDisabled: saveDisabled,
            onCancel: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    onDismiss()
                }
            },
            onPrimary: {
                Task {
                    await viewModel.saveConfig()
                    onSaveSuccess()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.md) {
                KumaTextField(label: "Config Name", value: $viewModel.newKubeConfigName, placeholder: "Staging Cluster")

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Kubeconfig Content (YAML)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { importKubeConfigFile() } label: {
                            Label("Import File", systemImage: "doc.badge.plus")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }

                    KumaCodeEditor(
                        code: $viewModel.newKubeConfigContent,
                        placeholder: "Paste kubeconfig YAML…",
                        minHeight: 120,
                        maxHeight: 120
                    )
                }
            }
        }
    }

    private func importKubeConfigFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Kubeconfig File"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                viewModel.newKubeConfigContent = content
                if viewModel.newKubeConfigName.isEmpty {
                    viewModel.newKubeConfigName = url.deletingPathExtension().lastPathComponent
                }
            }
        }
    }
}
