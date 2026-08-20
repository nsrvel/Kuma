import SwiftUI

public struct WelcomeStepView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: KumaSpacing.xxl) {
            // Hero Copy
            VStack(spacing: KumaSpacing.md) {
                Text("Your services,\none command away.")
                    .font(KumaFont.hero)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("A unified dashboard for port-forwards, containers, and background runners without the terminal clutter.")
                    .font(KumaFont.heroSubtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 480)
            }

            // Minimal Feature Tags — Pure, minimal icon + label
            HStack(spacing: KumaSpacing.xl) {
                featureTag(icon: "network", label: "Multi-Provider")
                featureTag(icon: "bolt.horizontal.fill", label: "Public Tunnels")
                featureTag(icon: "lock.shield.fill", label: "Local-First")
            }
            .padding(.top, KumaSpacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureTag(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Text(label)
                .font(KumaFont.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WelcomeStepView()
        .frame(width: 680, height: 500)
        .background(KumaColors.canvasBackground)
}
