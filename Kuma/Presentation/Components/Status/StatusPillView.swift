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
                KumaActivityIndicator(size: 10, color: color, lineWidth: 1.5)
            } else if showDot {
                ZStack {
                    if isGlowing {
                        // Zero-GPU glow — pre-composited opacity circle replaces .blur()
                        Circle()
                            .fill(color.opacity(0.45))
                            .frame(width: 8, height: 8)
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

/// Pure SwiftUI hardware-accelerated spinner.
/// Avoids AppKit NSProgressIndicator wrapper scaling/constraint conflicts during SwiftUI animations.
public struct KumaActivityIndicator: View {
    public var size: CGFloat
    public var color: Color
    public var lineWidth: CGFloat

    @State private var isAnimating: Bool = false

    public init(
        size: CGFloat = 12,
        color: Color = .secondary,
        lineWidth: CGFloat = 1.75
    ) {
        self.size = size
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.72)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 0.85).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
            .onDisappear {
                isAnimating = false
            }
    }
}
