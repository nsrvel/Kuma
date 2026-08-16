import SwiftUI

/// Dedicated native macOS sidebar row component for Group items.
/// Encapsulates inline name editing (VSCode / Finder standard) and context menu actions
/// while matching 100% of standard sidebar row metrics and typography.
public struct SidebarGroupRowView: View {
    public let group: ServiceGroup
    public let isSelected: Bool
    public let isEditing: Bool
    public let indentLevel: Int
    public let onSelect: () -> Void
    public let onCommitName: (String) -> Void
    public let onStartRename: () -> Void
    public let onDelete: () -> Void

    @State private var isHovering = false
    @State private var draftName: String = ""
    @FocusState private var isFocused: Bool

    public init(
        group: ServiceGroup,
        isSelected: Bool,
        isEditing: Bool,
        indentLevel: Int = 1,
        onSelect: @escaping () -> Void,
        onCommitName: @escaping (String) -> Void,
        onStartRename: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.group = group
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.indentLevel = indentLevel
        self.onSelect = onSelect
        self.onCommitName = onCommitName
        self.onStartRename = onStartRename
        self.onDelete = onDelete
        _draftName = State(initialValue: group.name)
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Native Indentation Spacer
            if indentLevel > 0 {
                Spacer().frame(width: CGFloat(indentLevel) * KumaTheme.Sidebar.indentWidth)
            }

            // Folder Icon
            Image(systemName: "folder.fill")
                .imageScale(.medium)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .padding(.trailing, 8)

            // Inline Editable Textfield OR Static Label
            if isEditing {
                TextField("", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                    .focused($isFocused)
                    .onSubmit {
                        onCommitName(draftName)
                    }
                    .onExitCommand {
                        onCommitName(group.name)
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused && isEditing {
                            onCommitName(draftName)
                        }
                    }
                    .onAppear {
                        draftName = group.name
                        isFocused = true
                    }
            } else {
                Text(group.name)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: KumaTheme.Sidebar.rowMinHeight)
        .contentShape(Rectangle())
        .padding(.vertical, KumaTheme.Sidebar.rowVerticalPadding)
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
        .contextMenu {
            Button {
                onStartRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        }
        .accessibilityLabel(group.name)
        .accessibilityAddTraits(.isButton)
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
        isSelected || isHovering
            ? AnyShapeStyle(Color.primary)
            : AnyShapeStyle(Color.secondary)
    }
}
