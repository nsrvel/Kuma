import SwiftUI

public struct KubeConfigItemRowView: View {
    let config: KubeConfig
    let isSelected: Bool
    let isLoadingNamespaces: Bool
    let hasConnectionError: Bool
    let contextToTest: String
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRefresh: () -> Void

    @State private var isHovered: Bool = false

    public init(
        config: KubeConfig,
        isSelected: Bool,
        isLoadingNamespaces: Bool,
        hasConnectionError: Bool,
        contextToTest: String,
        onSelect: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.config = config
        self.isSelected = isSelected
        self.isLoadingNamespaces = isLoadingNamespaces
        self.hasConnectionError = hasConnectionError
        self.contextToTest = contextToTest
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onRefresh = onRefresh
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(config.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                statusIndicator
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isLoadingNamespaces)
        .animation(.easeInOut(duration: 0.2), value: hasConnectionError)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.06) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 0.75)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            if !config.isDefault {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                Divider()
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            } else {
                Button { onRefresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            }
        }
        .onTapGesture { onSelect() }
    }

    private var subtitleText: String {
        if isSelected {
            return config.isDefault ? "Active Config · ~/.kube/config" : "Active Config"
        } else if config.isDefault {
            return "~/.kube/config"
        } else {
            return "Custom Config"
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if isLoadingNamespaces {
            HStack(spacing: 5) {
                KumaActivityIndicator(size: 10, color: .secondary, lineWidth: 1.5)
                Text("Connecting…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } else if hasConnectionError {
            Text("Unreachable")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.orange)
        } else {
            Text("Connected")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.green)
        }
    }
}
