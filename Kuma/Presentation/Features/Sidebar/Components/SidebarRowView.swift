import SwiftUI

public struct SidebarRowView: View {
    public let node: SidebarNode
    public let isSelected: Bool
    public let isExpanded: Bool
    public let indentLevel: Int
    public let onSelect: () -> Void
    public let onToggleExpand: () -> Void

    @State private var isHovering = false

    public init(
        node: SidebarNode,
        isSelected: Bool,
        isExpanded: Bool,
        indentLevel: Int,
        onSelect: @escaping () -> Void,
        onToggleExpand: @escaping () -> Void
    ) {
        self.node = node
        self.isSelected = isSelected
        self.isExpanded = isExpanded
        self.indentLevel = indentLevel
        self.onSelect = onSelect
        self.onToggleExpand = onToggleExpand
    }

    private var hasChildren: Bool { node.children != nil }
    private var showActions: Bool {
        if hasChildren {
            return isHovering || isSelected
        } else {
            return isHovering
        }
    }
    private var showChevronActive: Bool {
        isHovering || isSelected
    }

    public var body: some View {
        HStack(spacing: 0) {
            if indentLevel > 0 {
                Spacer().frame(width: CGFloat(indentLevel) * KumaTheme.Sidebar.indentWidth)
            }

            if !node.isSpecialHeader {
                iconView
                    .frame(width: 18, height: 18)
                    .padding(.trailing, 8)
            }

            Text(node.title)
                .font(.system(size: 13, weight: node.isSpecialHeader ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if let badge = node.badge, badge > 0, !showActions {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .transition(.opacity)
                }
                if showActions && !node.actions.isEmpty {
                    ForEach(node.actions) { action in
                        SidebarActionButton(action: action)
                            .transaction { $0.animation = nil }
                    }
                }
                if hasChildren {
                    SidebarChevron(isExpanded: isExpanded, onToggle: onToggleExpand)
                        .opacity(showChevronActive ? 1.0 : 0.0)
                }
            }
        }
        .frame(minHeight: KumaTheme.Sidebar.rowMinHeight)
        .contentShape(Rectangle())
        .padding(.vertical, node.isSpecialHeader ? 6 : KumaTheme.Sidebar.rowVerticalPadding)
        .padding(.horizontal, KumaTheme.Sidebar.rowHorizontalPadding)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: KumaTheme.Sidebar.rowCornerRadius, style: .continuous))
        .foregroundStyle(rowForeground)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .accessibilityLabel(node.title)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var iconView: some View {
        switch node.icon {
        case .system(let name):
            if !name.isEmpty {
                Image(systemName: name)
                    .imageScale(.medium)
                    .symbolRenderingMode(.hierarchical)
            }
        case .asset(let name):
            if !name.isEmpty {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.secondary.opacity(KumaTheme.Sidebar.selectedBgOpacity))
        } else if isHovering {
            return AnyShapeStyle(Color.secondary.opacity(KumaTheme.Sidebar.hoverBgOpacity))
        }
        return AnyShapeStyle(Color.clear)
    }

    private var rowForeground: some ShapeStyle {
        if node.isSpecialHeader {
            return AnyShapeStyle(Color.primary)
        }
        return isSelected || isHovering
            ? AnyShapeStyle(Color.primary)
            : AnyShapeStyle(Color.secondary)
    }
}

public struct SidebarEmptyPlaceholderRow: View {
    public let title: String
    public let indentLevel: Int

    public init(title: String, indentLevel: Int) {
        self.title = title
        self.indentLevel = indentLevel
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .italic()
                .foregroundStyle(Color.secondary.opacity(0.6))
            Spacer()
        }
        .padding(.leading, CGFloat(indentLevel) * KumaTheme.Sidebar.indentWidth + 24)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
    }
}
