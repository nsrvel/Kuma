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
    @State private var hoveredProviderID: UUID? = nil
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
                    VStack(alignment: .center, spacing: 8) {
                        Text("No providers configured yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            openAddForm()
                        } label: {
                            Label("Add First Provider", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLocked)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                } else if !showInlineForm {
                    VStack(spacing: 6) {
                        ForEach(providers) { provider in
                            let isSelected = (activeProviderID == provider.id)
                            let isHovered = (hoveredProviderID == provider.id)

                            HStack(spacing: 10) {
                                // Category Icon
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(provider.type.gradient)
                                        .frame(width: 24, height: 24)

                                    ProviderBrandIcon(category: provider.type, tunnelType: provider.tunnelType, size: 12.5)
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(provider.displayName)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(1)

                                    Text(provider.resolvedTarget)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isSelected {
                                    Text("Active")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.green)
                                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: isSelected)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.06) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.accentColor.opacity(0.35) : Color.clear,
                                        lineWidth: 0.75
                                    )
                            }
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                hoveredProviderID = hovering ? provider.id : nil
                            }
                            .contextMenu {
                                if !isLocked {
                                    Button {
                                        openEditForm(provider)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    if providers.count > 1 {
                                        Divider()

                                        Button(role: .destructive) {
                                            providerToDelete = provider
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .onTapGesture {
                                if !isLocked {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                        onSelectProvider(provider.id)
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

                    if !isLocked {
                        HStack {
                            Button {
                                openAddForm()
                            } label: {
                                Text("Add new provider")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(isAddHovered ? Color.primary : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .onHover { isAddHovered = $0 }
                            .help("Add new provider")

                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 4)
                    }
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
        }
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
            let newProv = Provider(
                id: UUID(),
                serviceID: serviceID,
                type: formType,
                label: label
            )
            onAddProvider(newProv)
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showInlineForm = false
        }
    }
}
