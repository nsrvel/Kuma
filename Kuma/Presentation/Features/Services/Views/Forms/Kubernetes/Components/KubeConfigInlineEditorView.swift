import SwiftUI

public struct KubeConfigInlineEditorView: View {
    @Bindable var viewModel: KubeConfigViewModel
    let onDismiss: () -> Void
    let onSaveSuccess: () -> Void

    @FocusState private var isInlineYamlFocused: Bool

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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    viewModel.editingKubeConfigID == nil ? "New Kube Config" : "Edit Kube Config",
                    systemImage: "doc.text.fill"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)

            KumaTextField(label: "Config Name", value: $viewModel.newKubeConfigName, placeholder: "Staging Cluster")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Kubeconfig Content (YAML)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
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
                    } label: {
                        Label("Import File", systemImage: "doc.badge.plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }

                TextEditor(text: $viewModel.newKubeConfigContent)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInlineYamlFocused)
                    .scrollIndicators(.hidden)
                    .frame(height: 120)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isInlineYamlFocused ? Color.accentColor : Color.primary.opacity(0.08),
                                lineWidth: isInlineYamlFocused ? 1.5 : 0.5
                            )
                    }
            }

            HStack {
                Spacer()
                Button("Save") {
                    Task {
                        await viewModel.saveConfig()
                        onSaveSuccess()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.newKubeConfigName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.newKubeConfigContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}
