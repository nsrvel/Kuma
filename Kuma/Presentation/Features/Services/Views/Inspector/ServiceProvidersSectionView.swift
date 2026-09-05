import SwiftUI

public struct ServiceProvidersSectionView: View {
    public let serviceID: UUID
    public let providers: [Provider]
    public let activeProviderID: UUID?
    public let isLocked: Bool
    public let onSelectProvider: (UUID) -> Void
    public let onAddProvider: (Provider) -> Void
    public let onUpdateProvider: (Provider) -> Void
    public let onDeleteProvider: (Provider) -> Void

    @State private var showInlineForm: Bool = false
    @State private var editingProviderID: UUID? = nil
    @State private var formType: ProviderCategory = .docker
    @State private var formLabel: String = ""
    @State private var isAddHovered: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var providerToDelete: Provider? = nil

    public init(
        serviceID: UUID,
        providers: [Provider],
        activeProviderID: UUID?,
        isLocked: Bool = false,
        onSelectProvider: @escaping (UUID) -> Void,
        onAddProvider: @escaping (Provider) -> Void,
        onUpdateProvider: @escaping (Provider) -> Void = { _ in },
        onDeleteProvider: @escaping (Provider) -> Void
    ) {
        self.serviceID = serviceID
        self.providers = providers
        self.activeProviderID = activeProviderID
        self.isLocked = isLocked
        self.onSelectProvider = onSelectProvider
        self.onAddProvider = onAddProvider
        self.onUpdateProvider = onUpdateProvider
        self.onDeleteProvider = onDeleteProvider
    }

    public var body: some View {
        KumaFormSection(
            icon: "square.stack.3d.down.right.fill",
            title: "Providers",
            subtitle: "Select runner configuration"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if providers.isEmpty && !showInlineForm {
                    emptyStateView
                } else if !showInlineForm {
                    providerListView
                } else {
                    ServiceProvidersInlineFormView(
                        isEditing: editingProviderID != nil,
                        formType: $formType,
                        formLabel: $formLabel,
                        onSave: { saveInlineForm() },
                        onCancel: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showInlineForm = false
                            }
                        }
                    )
                }
            }
            .confirmationDialog(
                "Delete Provider?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Provider", role: .destructive) {
                    if let provider = providerToDelete {
                        onDeleteProvider(provider)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete '\(providerToDelete?.displayName ?? "this provider")'?")
            }
            .onChange(of: isLocked) { _, locked in
                if locked && showInlineForm {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showInlineForm = false
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("No providers configured yet.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button { openAddForm() } label: { Label("Add First Provider", systemImage: "plus") }
                .buttonStyle(.bordered)
                .disabled(isLocked)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
    }

    private var providerListView: some View {
        VStack(spacing: 6) {
            ForEach(providers) { provider in
                ProviderItemRowView(
                    provider: provider,
                    isSelected: activeProviderID == provider.id,
                    isLocked: isLocked,
                    canDelete: providers.count > 1,
                    onSelect: { onSelectProvider(provider.id) },
                    onEdit: { openEditForm(provider) },
                    onDelete: {
                        providerToDelete = provider
                        showDeleteConfirmation = true
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
            Button { openAddForm() } label: {
                Text("Add new provider")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isAddHovered && !isLocked ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .opacity(isLocked ? 0.45 : 1.0)
            .onHover { isAddHovered = $0 }
            .help(isLocked ? "Stop service to add providers" : "Add new provider")
            .offset(y: 24)
            .padding(.horizontal, 4)
        }
        .padding(.bottom, 24)
    }

    private func openAddForm() {
        formLabel = ""
        formType = .docker
        editingProviderID = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showInlineForm = true
        }
    }

    private func openEditForm(_ provider: Provider) {
        formLabel = provider.label ?? ""
        formType = provider.type
        editingProviderID = provider.id
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showInlineForm = true
        }
    }

    private func saveInlineForm() {
        let trimmed = formLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let label: String? = trimmed.isEmpty ? nil : trimmed

        if let editingID = editingProviderID, let existing = providers.first(where: { $0.id == editingID }) {
            var updated = existing
            updated.label = label
            updated.type = formType
            updated.updatedAt = Date()
            onUpdateProvider(updated)
        } else {
            let newProv = Provider(id: UUID(), serviceID: serviceID, type: formType, label: label)
            onAddProvider(newProv)
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showInlineForm = false
        }
    }
}
