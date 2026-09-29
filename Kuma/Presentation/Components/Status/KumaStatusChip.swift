import SwiftUI

/// Semantic status capsule with dot, checkmark, or orbit leading mark.
struct KumaStatusChip: View {
    let title: String
    let tone: Color
    var showsOrbit: Bool = false
    var showsGlow: Bool = false
    var showsLeadingIndicator: Bool = true
    /// Same footprint as the status dot — used for “Active” provider selection.
    var showsCheckmarkLeading: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if showsLeadingIndicator {
                StatusPillLeadingIndicator(color: tone, showsOrbit: showsOrbit, showsGlow: showsGlow)
                    .frame(width: 10, height: 10)
            } else if showsCheckmarkLeading {
                checkmarkLeading
            }

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.85))
                .lineLimit(1)
                .contentTransition(.interpolate)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(tone.opacity(0.08)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(tone.opacity(0.22), lineWidth: 0.5)
        }
        .fixedSize()
        .animation(.smooth(duration: 0.25), value: title)
        .animation(.smooth(duration: 0.25), value: showsOrbit)
        .animation(.smooth(duration: 0.25), value: showsGlow)
        .accessibilityElement(children: .combine)
    }

    private var checkmarkLeading: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(tone)
            .frame(width: 10, height: 10)
    }
}

#Preview("Status chips") {
    VStack(alignment: .trailing, spacing: 8) {
        KumaStatusChip(
            title: "Active",
            tone: KumaStatus.runningIndicator,
            showsLeadingIndicator: false,
            showsCheckmarkLeading: true
        )
        KumaStatusChip(title: "Connecting…", tone: KumaStatus.transitionalIndicator, showsOrbit: true)
        KumaStatusChip(title: "Connected", tone: KumaStatus.runningIndicator, showsGlow: true)
        KumaStatusChip(title: "Unreachable", tone: KumaStatus.failedIndicator)
    }
    .padding()
}
