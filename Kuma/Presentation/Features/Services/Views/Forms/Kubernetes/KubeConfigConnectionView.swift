import SwiftUI

public struct KubeConfigConnectionView: View {
    @Bindable var viewModel: KubeConfigViewModel

    let isLocked: Bool
    let contextToTest: String
    let onConfigChanged: () -> Void

    @State private var isAddHovered: Bool = false

    public init(
        viewModel: KubeConfigViewModel,
        isLocked: Bool = false,
        contextToTest: String = "",
        onConfigChanged: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.isLocked = isLocked
        self.contextToTest = contextToTest
        self.onConfigChanged = onConfigChanged
    }

    public var body: some View {
        KumaFormSection(icon: "server.rack", title: "Kube Config") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.availableKubeConfigs.isEmpty && !viewModel.showInlineNewConfigForm {
                    emptyStateView
                } else if !viewModel.showInlineNewConfigForm {
                    configListView
                } else {
                    KubeConfigInlineEditorView(
                        viewModel: viewModel,
                        onDismiss: { viewModel.showInlineNewConfigForm = false },
                        onSaveSuccess: onConfigChanged
                    )
                }
            }
            .confirmationDialog("Delete Kubeconfig?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteConfig()
                        onConfigChanged()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: isLocked) { _, locked in
                if locked && viewModel.showInlineNewConfigForm {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.showInlineNewConfigForm = false
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("No kubeconfigs registered.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                viewModel.newKubeConfigName = ""
                viewModel.newKubeConfigContent = ""
                viewModel.editingKubeConfigID = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewModel.showInlineNewConfigForm = true
                }
            } label: {
                Label("Add Kubeconfig", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
    }

    private var configListView: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.availableKubeConfigs) { config in
                KubeConfigItemRowView(
                    config: config,
                    isSelected: viewModel.selectedKubeConfigID == config.id,
                    isLoadingNamespaces: viewModel.isLoadingNamespaces,
                    hasConnectionError: viewModel.connectionError != nil,
                    contextToTest: contextToTest,
                    onSelect: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            viewModel.selectedKubeConfigID = config.id
                        }
                        viewModel.testConnection(context: contextToTest)
                        onConfigChanged()
                    },
                    onEdit: {
                        viewModel.newKubeConfigName = config.name
                        viewModel.newKubeConfigContent = config.configContent
                        viewModel.editingKubeConfigID = config.id
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.showInlineNewConfigForm = true
                        }
                    },
                    onDelete: {
                        viewModel.selectedKubeConfigID = config.id
                        viewModel.showDeleteConfirmation = true
                    },
                    onRefresh: {
                        viewModel.selectedKubeConfigID = config.id
                        viewModel.testConnection(context: contextToTest)
                        onConfigChanged()
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.01))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .overlay(alignment: .bottomLeading) {
            Button {
                viewModel.newKubeConfigName = ""
                viewModel.newKubeConfigContent = ""
                viewModel.editingKubeConfigID = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewModel.showInlineNewConfigForm = true
                }
            } label: {
                Text("Add Kubeconfig")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isAddHovered ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            .onHover { isAddHovered = $0 }
            .help("Add Kubeconfig")
            .offset(y: 24)
            .padding(.horizontal, 4)
        }
        .padding(.bottom, 24)
    }
}
