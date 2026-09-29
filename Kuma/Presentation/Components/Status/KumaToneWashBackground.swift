import SwiftUI

/// Leading tone wash + hairline stroke for inspector banners and list rows.
struct KumaToneWashBackground: View {
    let tone: Color
    var washOpacity: Double
    var strokeOpacity: Double
    var baseOpacity: Double = 0.025
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(baseOpacity))
            .overlay {
                if washOpacity > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tone.opacity(washOpacity), tone.opacity(0)],
                                startPoint: .leading,
                                endPoint: UnitPoint(x: 0.7, y: 0.5)
                            )
                        )
                }
            }
            .overlay {
                if strokeOpacity > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(tone.opacity(strokeOpacity), lineWidth: 0.8)
                }
            }
    }
}

/// Neutral selected/hover chrome for inspector provider/kube list rows (not accent or status tone).
struct KumaInspectorListRowSelectionChrome: View {
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                isSelected
                    ? Color.primary.opacity(0.06)
                    : (isHovered ? Color.primary.opacity(0.03) : Color.clear)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(KumaColors.borderSubtle.opacity(0.85), lineWidth: 0.75)
                }
            }
    }
}
