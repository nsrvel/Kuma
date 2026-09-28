import SwiftUI

/// Full-width segmented control (corner radius aligned with `KumaTextField`).
public struct KumaFormSegmentBar<Option: Hashable>: View {
    public let options: [Option]
    @Binding public var selection: Option
    public let title: (Option) -> String
    public var accessibilityLabel: String

    @Namespace private var selectionNamespace

    private let trackInset: CGFloat = 4
    private var trackCornerRadius: CGFloat { KumaRadius.sm }
    /// Slightly softer than the track inset math so the active pill feels rounded, not square.
    private var segmentCornerRadius: CGFloat { 4 }

    public init(
        options: [Option],
        selection: Binding<Option>,
        title: @escaping (Option) -> String,
        accessibilityLabel: String = "Segment"
    ) {
        self.options = options
        self._selection = selection
        self.title = title
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                segmentCell(option)
            }
        }
        .padding(trackInset)
        .background {
            RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous)
                .fill(KumaColors.inputFieldFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous)
                .strokeBorder(KumaColors.inputFieldStroke, lineWidth: 0.5)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func segmentCell(_ option: Option) -> some View {
        let isSelected = selection == option
        Button {
            guard selection != option else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selection = option
            }
        } label: {
            Text(title(option))
                .font(KumaFont.body)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, KumaSpacing.xs)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous)
                            .fill(KumaColors.surfaceBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous)
                                    .strokeBorder(KumaColors.inputFieldStroke, lineWidth: 0.5)
                            }
                            .matchedGeometryEffect(id: "segmentSelection", in: selectionNamespace)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    struct Wrapper: View {
        @State private var mode = 0
        var body: some View {
            VStack(spacing: 24) {
                KumaFormSegmentBar(
                    options: [0, 1],
                    selection: $mode,
                    title: { $0 == 0 ? "Choose File" : "Paste YAML" }
                )
            }
            .padding(20)
            .frame(width: 420)
            .background(KumaColors.canvasBackground)
        }
    }
    return Wrapper()
}
