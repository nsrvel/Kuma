import SwiftUI

public struct StatusPillView: View {
    public let text: String
    public let color: Color
    public var showDot: Bool
    public var isGlowing: Bool
    public var isLoading: Bool

    public init(
        text: String,
        color: Color,
        showDot: Bool = true,
        isGlowing: Bool = false,
        isLoading: Bool = false
    ) {
        self.text = text
        self.color = color
        self.showDot = showDot
        self.isGlowing = isGlowing
        self.isLoading = isLoading
    }

    public var body: some View {
        HStack(spacing: 5) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else if showDot {
                ZStack {
                    if isGlowing {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .blur(radius: 1.5)
                    }
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                }
            }
            Text(text)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .fixedSize()

    }
}

public struct PortChipsView: View {
    public let ports: [Int]
    public var maxVisible: Int?

    public init(ports: [Int], maxVisible: Int? = nil, limit: Int? = nil) {
        self.ports = ports
        self.maxVisible = maxVisible ?? limit
    }

    public var body: some View {
        let limit = maxVisible ?? ports.count
        let visible = Array(ports.prefix(limit))
        let overflow = ports.count - visible.count

        HStack(spacing: 6) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                ForEach(visible, id: \.self) { port in
                    Text("\(port)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
                        }
                        .fixedSize()
                }
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 3)
                        .fixedSize()
                }
            }
        }
    }
}

