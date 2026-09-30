import AppKit
import SwiftUI

public struct KumaAttachedFileCard: View {
    public let path: String
    public var systemImage: String
    public var isLocked: Bool
    public var onChange: () -> Void
    public var onRemove: () -> Void
    public var onRevealInFinder: (() -> Void)?

    public init(
        path: String,
        systemImage: String = "doc",
        isLocked: Bool = false,
        onChange: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onRevealInFinder: (() -> Void)? = nil
    ) {
        self.path = path
        self.systemImage = systemImage
        self.isLocked = isLocked
        self.onChange = onChange
        self.onRemove = onRemove
        self.onRevealInFinder = onRevealInFinder
    }

    private var fileName: String {
        (path as NSString).lastPathComponent
    }

    private var subtitle: String {
        var meta: [String] = []
        if let size = KumaFileMetadata.fileSizeDescription(path: path) {
            meta.append(size)
        }
        meta.append(KumaFileMetadata.truncatedParentPath(path: path))
        return meta.joined(separator: " · ")
    }

    public var body: some View {
        HStack(alignment: .center, spacing: KumaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(KumaFont.bodyMedium)
                    .lineLimit(1)
                Text(subtitle)
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: KumaSpacing.sm)

            if !isLocked {
                HStack(spacing: KumaSpacing.xs) {
                    if let onRevealInFinder {
                        Button("Reveal", action: onRevealInFinder)
                            .buttonStyle(.plain)
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Change…", action: onChange)
                        .buttonStyle(.plain)
                        .font(KumaFont.caption)
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Remove file")
                }
            }
        }
        .padding(KumaSpacing.sm)
        .background(KumaColors.inputFieldFill, in: RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                .strokeBorder(KumaColors.inputFieldStroke, lineWidth: 0.5)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        KumaAttachedFileCard(
            path: "/Users/me/Projects/api/scripts/bootstrap.sh",
            systemImage: "terminal.fill",
            onChange: {},
            onRemove: {},
            onRevealInFinder: {}
        )
    }
    .padding()
    .frame(width: 420)
}
