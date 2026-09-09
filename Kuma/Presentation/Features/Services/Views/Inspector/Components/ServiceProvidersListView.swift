import SwiftUI

/// Provider rows list and Add Provider button view for ServiceProvidersSectionView.
public struct ServiceProvidersListView: View {
    public let providers: [Provider]
    public let activeProviderID: UUID?
    public let isLocked: Bool
    public let onSelectProvider: (UUID) -> Void
    public let onEdit: (Provider) -> Void
    public let onDelete: (Provider) -> Void
    public let onOpenAddForm: () -> Void

    @State private var isAddHovered: Bool = false

    public init(
        providers: [Provider],
        activeProviderID: UUID?,
        isLocked: Bool,
        onSelectProvider: @escaping (UUID) -> Void,
        onEdit: @escaping (Provider) -> Void,
        onDelete: @escaping (Provider) -> Void,
        onOpenAddForm: @escaping () -> Void
    ) {
        self.providers = providers
        self.activeProviderID = activeProviderID
        self.isLocked = isLocked
        self.onSelectProvider = onSelectProvider
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onOpenAddForm = onOpenAddForm
    }

    public var body: some View {
        VStack(spacing: 6) {
            ForEach(providers) { provider in
                ProviderItemRowView(
                    provider: provider,
                    isSelected: activeProviderID == provider.id,
                    isLocked: isLocked,
                    canDelete: providers.count > 1,
                    onSelect: { onSelectProvider(provider.id) },
                    onEdit: { onEdit(provider) },
                    onDelete: { onDelete(provider) }
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
            Button { onOpenAddForm() } label: {
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
}
