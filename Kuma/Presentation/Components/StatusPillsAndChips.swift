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

public struct PortChipsView: View {
    public let ports: [Int]
    public var maxVisible: Int?

    public init(ports: [Int], maxVisible: Int? = nil, limit: Int? = nil) {
        self.ports = ports
        self.maxVisible = maxVisible ?? limit
    }

    public var body: some View {
        let limit = maxVisible ?? ports.count
        let overflow = max(0, ports.count - limit)

        HStack(spacing: 6) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                // Direct slice iteration — zero array allocation
                ForEach(ports.prefix(limit), id: \.self) { port in
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

// MARK: - ProviderBrandIcon

public struct ProviderBrandIcon: View {
    public let category: ProviderCategory
    public var tunnelType: String? = nil
    public var size: CGFloat = 14

    public init(category: ProviderCategory, tunnelType: String? = nil, size: CGFloat = 14) {
        self.category = category
        self.tunnelType = tunnelType
        self.size = size
    }

    public var body: some View {
        Group {
            switch category {
            case .docker:
                DockerBrandVector()
                    .frame(width: size, height: size)
            case .kubernetes:
                KubernetesBrandVector()
                    .frame(width: size, height: size)
            case .podman:
                PodmanBrandVector()
                    .frame(width: size, height: size)
            case .shell:
                Image(systemName: "terminal.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .ssh:
                Image(systemName: "server.rack")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .httpCheck:
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .tunnel:
                Image(systemName: "cloud.bolt.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .processMonitor:
                Image(systemName: "cpu.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Brand Vector Shapes (Pure SwiftUI Bezier - Zero Memory Overhead)

/// Official Docker Brand Vector (1:1 with Official Moby Whale & 9-Box Container Grid, Prominent Scale)
public struct DockerBrandVector: View {
    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                // Scale normalized to 24x24 viewBox with 1.15x prominent scale centered
                let baseScale = min(size.width, size.height) / 24.0 * 1.16
                let offsetX = (size.width - 24.0 * baseScale) / 2.0
                let offsetY = (size.height - 24.0 * baseScale) / 2.0 + (0.5 * baseScale)

                let scaleX = baseScale
                let scaleY = baseScale

                // Container dimensions (exact official Docker 9-container stack)
                let cW = 2.12 * scaleX
                let cH = 1.89 * scaleY
                let cr = 0.22 * scaleX

                // 9 Container Boxes:
                // Row 1 (top): 1 box
                ctx.fill(
                    Path(roundedRect: CGRect(x: offsetX + 11.03 * scaleX, y: offsetY + 3.39 * scaleY, width: cW, height: cH), cornerRadius: cr),
                    with: .foreground
                )

                // Row 2 (middle): 3 boxes
                let row2X: [CGFloat] = [5.14, 8.10, 11.03]
                for x in row2X {
                    ctx.fill(
                        Path(roundedRect: CGRect(x: offsetX + x * scaleX, y: offsetY + 6.10 * scaleY, width: cW, height: cH), cornerRadius: cr),
                        with: .foreground
                    )
                }

                // Row 3 (bottom): 5 boxes
                let row3X: [CGFloat] = [2.22, 5.14, 8.10, 11.03, 13.98]
                for x in row3X {
                    ctx.fill(
                        Path(roundedRect: CGRect(x: offsetX + x * scaleX, y: offsetY + 8.82 * scaleY, width: cW, height: cH), cornerRadius: cr),
                        with: .foreground
                    )
                }

                // Official Moby Whale Body Silhouette
                var whale = Path()
                // Start at top of tail fluke
                whale.move(to: CGPoint(x: offsetX + 23.76 * scaleX, y: offsetY + 9.89 * scaleY))
                // Tail fluke curves
                whale.addCurve(
                    to: CGPoint(x: offsetX + 21.81 * scaleX, y: offsetY + 9.38 * scaleY),
                    control1: CGPoint(x: offsetX + 23.70 * scaleX, y: offsetY + 9.84 * scaleY),
                    control2: CGPoint(x: offsetX + 23.09 * scaleX, y: offsetY + 9.38 * scaleY)
                )
                whale.addCurve(
                    to: CGPoint(x: offsetX + 20.80 * scaleX, y: offsetY + 9.47 * scaleY),
                    control1: CGPoint(x: offsetX + 21.47 * scaleX, y: offsetY + 9.38 * scaleY),
                    control2: CGPoint(x: offsetX + 21.13 * scaleX, y: offsetY + 9.41 * scaleY)
                )
                // Upper tail fin / water spray cutout
                whale.addCurve(
                    to: CGPoint(x: offsetX + 19.08 * scaleX, y: offsetY + 6.90 * scaleY),
                    control1: CGPoint(x: offsetX + 20.55 * scaleX, y: offsetY + 7.77 * scaleY),
                    control2: CGPoint(x: offsetX + 19.15 * scaleX, y: offsetY + 6.94 * scaleY)
                )
                whale.addLine(to: CGPoint(x: offsetX + 18.74 * scaleX, y: offsetY + 6.70 * scaleY))
                whale.addLine(to: CGPoint(x: offsetX + 18.51 * scaleX, y: offsetY + 7.03 * scaleY))
                whale.addCurve(
                    to: CGPoint(x: offsetX + 17.90 * scaleX, y: offsetY + 8.46 * scaleY),
                    control1: CGPoint(x: offsetX + 18.23 * scaleX, y: offsetY + 7.47 * scaleY),
                    control2: CGPoint(x: offsetX + 18.02 * scaleX, y: offsetY + 7.95 * scaleY)
                )
                whale.addCurve(
                    to: CGPoint(x: offsetX + 18.30 * scaleX, y: offsetY + 11.12 * scaleY),
                    control1: CGPoint(x: offsetX + 17.67 * scaleX, y: offsetY + 9.43 * scaleY),
                    control2: CGPoint(x: offsetX + 17.81 * scaleX, y: offsetY + 10.34 * scaleY)
                )
                // Back shelf right under containers
                whale.addCurve(
                    to: CGPoint(x: offsetX + 16.56 * scaleX, y: offsetY + 11.54 * scaleY),
                    control1: CGPoint(x: offsetX + 17.71 * scaleX, y: offsetY + 11.45 * scaleY),
                    control2: CGPoint(x: offsetX + 16.75 * scaleX, y: offsetY + 11.53 * scaleY)
                )
                whale.addLine(to: CGPoint(x: offsetX + 0.75 * scaleX, y: offsetY + 11.54 * scaleY))
                // Front snout round curve
                whale.addCurve(
                    to: CGPoint(x: offsetX + 0.00 * scaleX, y: offsetY + 12.29 * scaleY),
                    control1: CGPoint(x: offsetX + 0.34 * scaleX, y: offsetY + 11.54 * scaleY),
                    control2: CGPoint(x: offsetX + 0.00 * scaleX, y: offsetY + 11.88 * scaleY)
                )
                // Head front curve down to chin
                whale.addCurve(
                    to: CGPoint(x: offsetX + 0.69 * scaleX, y: offsetY + 16.35 * scaleY),
                    control1: CGPoint(x: offsetX + 0.00 * scaleX, y: offsetY + 13.80 * scaleY),
                    control2: CGPoint(x: offsetX + 0.25 * scaleX, y: offsetY + 15.25 * scaleY)
                )
                // Chin to belly
                whale.addCurve(
                    to: CGPoint(x: offsetX + 3.10 * scaleX, y: offsetY + 19.47 * scaleY),
                    control1: CGPoint(x: offsetX + 1.24 * scaleX, y: offsetY + 17.78 * scaleY),
                    control2: CGPoint(x: offsetX + 2.05 * scaleX, y: offsetY + 18.83 * scaleY)
                )
                // Underbelly swoop
                whale.addCurve(
                    to: CGPoint(x: offsetX + 8.38 * scaleX, y: offsetY + 20.61 * scaleY),
                    control1: CGPoint(x: offsetX + 4.28 * scaleX, y: offsetY + 20.19 * scaleY),
                    control2: CGPoint(x: offsetX + 6.20 * scaleX, y: offsetY + 20.61 * scaleY)
                )
                // Belly upward to tail base
                whale.addCurve(
                    to: CGPoint(x: offsetX + 15.13 * scaleX, y: offsetY + 18.95 * scaleY),
                    control1: CGPoint(x: offsetX + 10.74 * scaleX, y: offsetY + 20.61 * scaleY),
                    control2: CGPoint(x: offsetX + 13.12 * scaleX, y: offsetY + 19.95 * scaleY)
                )
                whale.addCurve(
                    to: CGPoint(x: offsetX + 17.74 * scaleX, y: offsetY + 16.81 * scaleY),
                    control1: CGPoint(x: offsetX + 16.11 * scaleX, y: offsetY + 18.38 * scaleY),
                    control2: CGPoint(x: offsetX + 16.99 * scaleX, y: offsetY + 17.66 * scaleY)
                )
                whale.addCurve(
                    to: CGPoint(x: offsetX + 20.30 * scaleX, y: offsetY + 12.41 * scaleY),
                    control1: CGPoint(x: offsetX + 18.99 * scaleX, y: offsetY + 15.39 * scaleY),
                    control2: CGPoint(x: offsetX + 19.74 * scaleX, y: offsetY + 13.81 * scaleY)
                )
                whale.addLine(to: CGPoint(x: offsetX + 20.52 * scaleX, y: offsetY + 12.41 * scaleY))
                // Lower tail fluke curve
                whale.addCurve(
                    to: CGPoint(x: offsetX + 23.20 * scaleX, y: offsetY + 11.40 * scaleY),
                    control1: CGPoint(x: offsetX + 21.89 * scaleX, y: offsetY + 12.41 * scaleY),
                    control2: CGPoint(x: offsetX + 22.74 * scaleX, y: offsetY + 11.86 * scaleY)
                )
                whale.addCurve(
                    to: CGPoint(x: offsetX + 23.91 * scaleX, y: offsetY + 10.35 * scaleY),
                    control1: CGPoint(x: offsetX + 23.51 * scaleX, y: offsetY + 11.11 * scaleY),
                    control2: CGPoint(x: offsetX + 23.75 * scaleX, y: offsetY + 10.75 * scaleY)
                )
                whale.addLine(to: CGPoint(x: offsetX + 23.76 * scaleX, y: offsetY + 9.89 * scaleY))
                whale.closeSubpath()

                ctx.fill(whale, with: .foreground)

                // Eye (Whale eye dot positioned accurately)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: offsetX + 3.45 * scaleX, y: offsetY + 13.85 * scaleY, width: 0.95 * scaleX, height: 0.95 * scaleY)),
                    with: .color(.black.opacity(0.4))
                )
            }
        }
    }
}

/// Official Kubernetes 7-Spoke Helm Wheel Vector (Balanced Scale)
public struct KubernetesBrandVector: View {
    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.455
                let innerRadius = radius * 0.44

                // Outer 7-sided polygon / rim
                var rim = Path()
                let spokeCount = 7
                for i in 0..<spokeCount {
                    let angle = (Double(i) * (360.0 / Double(spokeCount)) - 90.0) * .pi / 180.0
                    let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
                    if i == 0 { rim.move(to: pt) } else { rim.addLine(to: pt) }
                }
                rim.closeSubpath()
                ctx.stroke(rim, with: .foreground, style: StrokeStyle(lineWidth: max(1.2, size.width * 0.11), lineJoin: .round))

                // Center hub
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - innerRadius * 0.55, y: center.y - innerRadius * 0.55, width: innerRadius * 1.1, height: innerRadius * 1.1)), with: .foreground)

                // 7 Spokes connecting hub to rim
                for i in 0..<spokeCount {
                    let angle = (Double(i) * (360.0 / Double(spokeCount)) - 90.0) * .pi / 180.0
                    var spoke = Path()
                    spoke.move(to: center)
                    spoke.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius))
                    ctx.stroke(spoke, with: .foreground, style: StrokeStyle(lineWidth: max(1.0, size.width * 0.085)))
                }
            }
        }
    }
}

/// Official Podman Seal Mascot Vector (Refined Authentic Selkie Seal Mascot - Sleek & Centered)
public struct PodmanBrandVector: View {
    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let baseScale = min(size.width, size.height) / 24.0
                let offsetX = (size.width - 24.0 * baseScale) / 2.0
                let offsetY = (size.height - 24.0 * baseScale) / 2.0

                let scaleX = baseScale
                let scaleY = baseScale

                // Solid seal head silhouette (flatter head crown, sleek tapered snout & neck)
                var head = Path()
                // Top flattened crown
                head.move(to: CGPoint(x: offsetX + 12.0 * scaleX, y: offsetY + 3.0 * scaleY))
                // Right forehead & temple
                head.addCurve(
                    to: CGPoint(x: offsetX + 20.8 * scaleX, y: offsetY + 11.5 * scaleY),
                    control1: CGPoint(x: offsetX + 17.5 * scaleX, y: offsetY + 3.0 * scaleY),
                    control2: CGPoint(x: offsetX + 20.8 * scaleX, y: offsetY + 6.8 * scaleY)
                )
                // Right cheek to tapered neck
                head.addCurve(
                    to: CGPoint(x: offsetX + 17.2 * scaleX, y: offsetY + 21.0 * scaleY),
                    control1: CGPoint(x: offsetX + 20.8 * scaleX, y: offsetY + 16.0 * scaleY),
                    control2: CGPoint(x: offsetX + 19.0 * scaleX, y: offsetY + 19.5 * scaleY)
                )
                // Bottom chin / neck curve
                head.addCurve(
                    to: CGPoint(x: offsetX + 6.8 * scaleX, y: offsetY + 21.0 * scaleY),
                    control1: CGPoint(x: offsetX + 14.5 * scaleX, y: offsetY + 22.0 * scaleY),
                    control2: CGPoint(x: offsetX + 9.5 * scaleX, y: offsetY + 22.0 * scaleY)
                )
                // Left tapered neck to cheek
                head.addCurve(
                    to: CGPoint(x: offsetX + 3.2 * scaleX, y: offsetY + 11.5 * scaleY),
                    control1: CGPoint(x: offsetX + 5.0 * scaleX, y: offsetY + 19.5 * scaleY),
                    control2: CGPoint(x: offsetX + 3.2 * scaleX, y: offsetY + 16.0 * scaleY)
                )
                // Left temple to top crown
                head.addCurve(
                    to: CGPoint(x: offsetX + 12.0 * scaleX, y: offsetY + 3.0 * scaleY),
                    control1: CGPoint(x: offsetX + 3.2 * scaleX, y: offsetY + 6.8 * scaleY),
                    control2: CGPoint(x: offsetX + 6.5 * scaleX, y: offsetY + 3.0 * scaleY)
                )
                head.closeSubpath()

                // Draw filled seal head
                ctx.fill(head, with: .foreground)

                // Eyes (Subtle almond/oval shape)
                let eyeW = 2.0 * scaleX
                let eyeH = 2.4 * scaleY
                ctx.fill(
                    Path(ellipseIn: CGRect(x: offsetX + 7.0 * scaleX, y: offsetY + 8.5 * scaleY, width: eyeW, height: eyeH)),
                    with: .color(.black.opacity(0.55))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: offsetX + 15.0 * scaleX, y: offsetY + 8.5 * scaleY, width: eyeW, height: eyeH)),
                    with: .color(.black.opacity(0.55))
                )

                // Snout / Nose (Triangular rounded seal nose)
                let noseW = 3.6 * scaleX
                let noseH = 2.4 * scaleY
                ctx.fill(
                    Path(ellipseIn: CGRect(x: offsetX + 10.2 * scaleX, y: offsetY + 12.2 * scaleY, width: noseW, height: noseH)),
                    with: .color(.black.opacity(0.6))
                )

                // Whiskers (3 left, 3 right spreading naturally)
                var whiskers = Path()
                // Left whiskers
                whiskers.move(to: CGPoint(x: offsetX + 9.5 * scaleX, y: offsetY + 13.5 * scaleY))
                whiskers.addLine(to: CGPoint(x: offsetX + 4.8 * scaleX, y: offsetY + 12.2 * scaleY))

                whiskers.move(to: CGPoint(x: offsetX + 9.5 * scaleX, y: offsetY + 14.5 * scaleY))
                whiskers.addLine(to: CGPoint(x: offsetX + 4.2 * scaleX, y: offsetY + 15.0 * scaleY))

                whiskers.move(to: CGPoint(x: offsetX + 9.5 * scaleX, y: offsetY + 15.5 * scaleY))
                whiskers.addLine(to: CGPoint(x: offsetX + 5.2 * scaleX, y: offsetY + 17.5 * scaleY))

                // Right whiskers
                whiskers.move(to: CGPoint(x: offsetX + 14.5 * scaleX, y: offsetY + 13.5 * scaleY))
                whiskers.addLine(to: CGPoint(x: offsetX + 19.2 * scaleX, y: offsetY + 12.2 * scaleY))

                whiskers.move(to: CGPoint(x: offsetX + 14.5 * scaleX, y: offsetY + 14.5 * scaleY))
                whiskers.addLine(to: CGPoint(x: offsetX + 19.8 * scaleX, y: offsetY + 15.0 * scaleY))

                whiskers.move(to: CGPoint(x: offsetX + 14.5 * scaleX, y: offsetY + 15.5 * scaleY))
                whiskers.addLine(to: CGPoint(x: offsetX + 18.8 * scaleX, y: offsetY + 17.5 * scaleY))

                ctx.stroke(
                    whiskers,
                    with: .color(.black.opacity(0.45)),
                    style: StrokeStyle(lineWidth: max(0.9, size.width * 0.05), lineCap: .round)
                )
            }
        }
    }
}

/// Universal '>_' Terminal Prompt Vector
public struct ShellPromptVector: View {
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { ctx, size in
                let scaleX = size.width / 24.0
                let scaleY = size.height / 24.0

                // '>' Prompt
                var chevron = Path()
                chevron.move(to: CGPoint(x: 3.5 * scaleX, y: 5.5 * scaleY))
                chevron.addLine(to: CGPoint(x: 10.5 * scaleX, y: 12.0 * scaleY))
                chevron.addLine(to: CGPoint(x: 3.5 * scaleX, y: 18.5 * scaleY))
                ctx.stroke(chevron, with: .foreground, style: StrokeStyle(lineWidth: max(1.4, size.width * 0.12), lineCap: .round, lineJoin: .round))

                // '_' Underscore cursor
                var cursor = Path()
                cursor.move(to: CGPoint(x: 13.0 * scaleX, y: 18.5 * scaleY))
                cursor.addLine(to: CGPoint(x: 20.5 * scaleX, y: 18.5 * scaleY))
                ctx.stroke(cursor, with: .foreground, style: StrokeStyle(lineWidth: max(1.4, size.width * 0.12), lineCap: .round))
            }
        }
    }
}

/// Official Cloudflare Cloud Vector
public struct CloudflareBrandVector: View {
    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let scaleX = size.width / 24.0
                let scaleY = size.height / 24.0

                var cloud = Path()
                cloud.move(to: CGPoint(x: 19.5 * scaleX, y: 17.5 * scaleY))
                cloud.addLine(to: CGPoint(x: 4.5 * scaleX, y: 17.5 * scaleY))
                cloud.addCurve(
                    to: CGPoint(x: 4.5 * scaleX, y: 11.5 * scaleY),
                    control1: CGPoint(x: 2.0 * scaleX, y: 17.5 * scaleY),
                    control2: CGPoint(x: 2.0 * scaleX, y: 11.5 * scaleY)
                )
                cloud.addCurve(
                    to: CGPoint(x: 10.5 * scaleX, y: 7.0 * scaleY),
                    control1: CGPoint(x: 4.5 * scaleX, y: 8.5 * scaleY),
                    control2: CGPoint(x: 7.5 * scaleX, y: 6.5 * scaleY)
                )
                cloud.addCurve(
                    to: CGPoint(x: 18.5 * scaleX, y: 10.5 * scaleY),
                    control1: CGPoint(x: 15.0 * scaleX, y: 6.5 * scaleY),
                    control2: CGPoint(x: 18.0 * scaleX, y: 8.5 * scaleY)
                )
                cloud.addCurve(
                    to: CGPoint(x: 19.5 * scaleX, y: 17.5 * scaleY),
                    control1: CGPoint(x: 21.5 * scaleX, y: 11.5 * scaleY),
                    control2: CGPoint(x: 22.0 * scaleX, y: 17.5 * scaleY)
                )
                cloud.closeSubpath()

                ctx.fill(cloud, with: .foreground)
            }
        }
    }
}

/// Official Ngrok Curved Archway 'n' Vector
public struct NgrokBrandVector: View {
    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let scaleX = size.width / 20.0
                let scaleY = size.height / 20.0

                // Iconic ngrok lower-case 'n' archway geometry
                var nPath = Path()
                // Left vertical stem
                nPath.move(to: CGPoint(x: 4.5 * scaleX, y: 16.5 * scaleY))
                nPath.addLine(to: CGPoint(x: 4.5 * scaleX, y: 4.5 * scaleY))
                // Top rounded shoulder curve
                nPath.addCurve(
                    to: CGPoint(x: 15.5 * scaleX, y: 8.5 * scaleY),
                    control1: CGPoint(x: 4.5 * scaleX, y: 3.5 * scaleY),
                    control2: CGPoint(x: 15.5 * scaleX, y: 3.5 * scaleY)
                )
                // Right vertical stem
                nPath.addLine(to: CGPoint(x: 15.5 * scaleX, y: 16.5 * scaleY))

                ctx.stroke(
                    nPath,
                    with: .foreground,
                    style: StrokeStyle(
                        lineWidth: max(2.0, size.width * 0.19),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
    }
}

