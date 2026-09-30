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
                .font(node.isSpecialHeader ? .system(size: 12, weight: .medium) : .system(size: 13, weight: .regular))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
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
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            if node.isSpecialHeader {
                onToggleExpand()
            } else {
                onSelect()
            }
        }
        .animation(.easeInOut(duration: 0.14), value: isSelected)
        .accessibilityLabel(node.title)
        .accessibilityAddTraits(node.isSpecialHeader ? .isHeader : .isButton)
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
        if node.isSpecialHeader {
            return AnyShapeStyle(Color.clear)
        }
        if isSelected {
            return AnyShapeStyle(Color.secondary.opacity(KumaTheme.Sidebar.selectedBgOpacity))
        } else if isHovering {
            return AnyShapeStyle(Color.secondary.opacity(KumaTheme.Sidebar.hoverBgOpacity))
        }
        return AnyShapeStyle(Color.clear)
    }

    private var rowForeground: some ShapeStyle {
        if node.isSpecialHeader {
            return AnyShapeStyle(Color.primary.opacity(0.88))
        }
        return isSelected || isHovering
            ? AnyShapeStyle(Color.primary)
            : AnyShapeStyle(Color.secondary)
    }
}

