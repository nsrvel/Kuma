import SwiftUI

// MARK: - KubeConfigConnectionView (100% V3 Match)

public struct KubeConfigConnectionView: View {
    @Bindable var viewModel: KubeConfigViewModel
    @FocusState private var isInlineYamlFocused: Bool

    let isLocked: Bool
    let contextToTest: String
    let onConfigChanged: () -> Void

    @State private var hoveredConfigID: UUID? = nil
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
        KumaFormSection(
            icon: "server.rack",
            title: "Kube Config",
            subtitle: "Select cluster credentials"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.availableKubeConfigs.isEmpty && !viewModel.showInlineNewConfigForm {
                    VStack(alignment: .center, spacing: 8) {
                        Text("No Kube Config files registered yet.")
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
                            Label("Register First Config", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                } else if !viewModel.showInlineNewConfigForm {
                    VStack(spacing: 6) {
                        ForEach(viewModel.availableKubeConfigs) { config in
                            let isSelected = viewModel.selectedKubeConfigID == config.id
                            let isHovered = hoveredConfigID == config.id

                            HStack(spacing: 12) {
                                Circle()
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.12))
                                    .frame(width: 6, height: 6)

                                Text(config.name)
                                    .font(.system(size: 12))

                                Spacer()

                                if isSelected {
                                    if isLocked {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    } else if viewModel.isLoadingNamespaces {
                                        ProgressView()
                                            .controlSize(.small)
                                            .scaleEffect(0.6)
                                    } else if viewModel.connectionSuccess {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.green)
                                    } else if viewModel.connectionError != nil {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.06) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                                        lineWidth: 0.75
                                    )
                            }
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    viewModel.newKubeConfigName = config.name
                                    viewModel.newKubeConfigContent = config.configContent
                                    viewModel.editingKubeConfigID = config.id
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        viewModel.showInlineNewConfigForm = true
                                    }
                                } label: {
                                    Label(config.isDefault ? "View / Edit" : "Edit", systemImage: "pencil")
                                }

                                Button {
                                    viewModel.selectedKubeConfigID = config.id
                                    viewModel.testConnection(context: contextToTest)
                                    onConfigChanged()
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }

                                if !config.isDefault {
                                    Divider()

                                    Button(role: .destructive) {
                                        viewModel.selectedKubeConfigID = config.id
                                        viewModel.showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onTapGesture {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    viewModel.selectedKubeConfigID = config.id
                                }
                                viewModel.testConnection(context: contextToTest)
                                onConfigChanged()
                            }
                            .onHover { hovering in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    if hovering {
                                        hoveredConfigID = config.id
                                    } else if hoveredConfigID == config.id {
                                        hoveredConfigID = nil
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.01))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )

                    HStack {
                        Button {
                            viewModel.newKubeConfigName = ""
                            viewModel.newKubeConfigContent = ""
                            viewModel.editingKubeConfigID = nil
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.showInlineNewConfigForm = true
                            }
                        } label: {
                            Text("Add new config")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isAddHovered ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            isAddHovered = hovering
                        }
                        .help("Add new config")

                        Spacer()
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 4)

                    if viewModel.connectionError != nil {
                        KumaNoticeBanner(
                            style: .warning,
                            title: "Offline Mode / Unreachable Cluster",
                            message: "Unable to connect automatically. Fell back to manual text input for namespaces & contexts below.",
                            actionIcon: "arrow.clockwise",
                            actionHint: "Retry connection test",
                            onAction: {
                                viewModel.testConnection(context: contextToTest)
                                onConfigChanged()
                            }
                        )
                        .padding(.top, 6)
                    }
                } else {
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
                                    viewModel.showInlineNewConfigForm = false
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
                            Text("Kubeconfig Content (YAML)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)

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
                                    onConfigChanged()
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
            .confirmationDialog(
                "Are you sure you want to delete this Kube Config?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Config", role: .destructive) {
                    Task {
                        await viewModel.deleteConfig()
                        onConfigChanged()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var vm = KubeConfigViewModel()
        var body: some View {
            KubeConfigConnectionView(viewModel: vm)
                .padding()
                .frame(width: 480)
                .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}
