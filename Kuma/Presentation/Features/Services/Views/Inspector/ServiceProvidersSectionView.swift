import SwiftUI

public struct ServiceProvidersSectionView: View {
    public let serviceID: UUID
    public let providers: [Provider]
    @Binding public var activeProviderID: UUID?
    public let isEditing: Bool
    public let isRunning: Bool
    public let onSelectProvider: (UUID) -> Void
    public let onEditProviderDetails: (Provider) -> Void
    public let onSaveProvider: (Provider) -> Void
    public let onDeleteProvider: (Provider) -> Void

    @State private var hoveredProviderID: UUID? = nil
    @State private var isAddHovered: Bool = false
    @State private var showInlineForm: Bool = false
    @State private var editingProviderID: UUID? = nil

    // Inline Form State
    @State private var formLabel: String = ""
    @State private var formType: ProviderCategory = .docker
    @State private var showDeleteConfirmation: Bool = false
    @State private var providerToDelete: Provider? = nil

    public init(
        serviceID: UUID,
        providers: [Provider],
        activeProviderID: Binding<UUID?>,
        isEditing: Bool = true,
        isRunning: Bool = false,
        onSelectProvider: @escaping (UUID) -> Void = { _ in },
        onEditProviderDetails: @escaping (Provider) -> Void = { _ in },
        onSaveProvider: @escaping (Provider) -> Void = { _ in },
        onDeleteProvider: @escaping (Provider) -> Void = { _ in }
    ) {
        self.serviceID = serviceID
        self.providers = providers
        self._activeProviderID = activeProviderID
        self.isEditing = isEditing
        self.isRunning = isRunning
        self.onSelectProvider = onSelectProvider
        self.onEditProviderDetails = onEditProviderDetails
        self.onSaveProvider = onSaveProvider
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

                                    Image(systemName: provider.type.icon)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(provider.displayName)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(1)

                                    if isSelected {
                                        Text("Active Provider")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Text(provider.resolvedTarget)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                // Native Navigation Chevron Button
                                Button {
                                    onEditProviderDetails(provider)
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.secondary.opacity(0.45))
                                        .frame(width: 20, height: 20)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Edit \(provider.displayName) Configuration")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.accentColor.opacity(0.35) : Color.clear,
                                        lineWidth: 0.75
                                    )
                            }
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    onEditProviderDetails(provider)
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
                            .onTapGesture {
                                if !isRunning {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                        activeProviderID = provider.id
                                    }
                                    onSelectProvider(provider.id)
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
                } else {
                    // Inline Add / Edit Provider Form
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(
                                editingProviderID == nil ? "New Provider" : "Edit Provider",
                                systemImage: "square.stack.3d.down.right.fill"
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showInlineForm = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 2)

                        KumaRowPickerField(
                            label: "Provider Type",
                            description: "Select runtime engine.",
                            options: ProviderCategory.allCases.map(\.rawValue),
                            selection: Binding(
                                get: { formType.rawValue },
                                set: { if let cat = ProviderCategory(rawValue: $0) { formType = cat } }
                            ),
                            titleResolver: { (ProviderCategory(rawValue: $0) ?? .docker).sidebarLabel }
                        )

                        Divider().opacity(0.4)

                        KumaTextField(
                            label: "Custom Label (Optional)",
                            value: $formLabel,
                            placeholder: "Staging"
                        )

                        HStack {
                            Spacer()
                            Button("Save") {
                                saveInlineForm()
                            }
                            .buttonStyle(.borderedProminent)
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
        formLabel = provider.displayName
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
            onSaveProvider(updated)
        } else {
            let newProv = Provider(
                id: UUID(),
                serviceID: serviceID,
                type: formType,
                label: label
            )
            onSaveProvider(newProv)
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showInlineForm = false
        }
    }
}




