import SwiftUI

/// Reusable key-value row for inspector detail panels.
/// Supports monospaced values, inline badges, and optional secondary hints.
public struct InspectorKeyValueRow: View {
    public let key: String
    public let value: String
    public var isMonospaced: Bool
    public var isBadge: Bool
    public var badgeColor: Color?

    public init(
        key: String,
        value: String,
        isMonospaced: Bool = false,
        isBadge: Bool = false,
        badgeColor: Color? = nil
    ) {
        self.key = key
        self.value = value
        self.isMonospaced = isMonospaced
        self.isBadge = isBadge
        self.badgeColor = badgeColor
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Spacer()

            if isBadge {
                let color = badgeColor ?? .secondary
                Text(value)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Text(value.isEmpty ? "—" : value)
                    .font(isMonospaced ? .system(size: 11.5, weight: .regular, design: .monospaced) : .system(size: 11.5, weight: .medium))
                    .foregroundStyle(value.isEmpty ? .tertiary : .primary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
