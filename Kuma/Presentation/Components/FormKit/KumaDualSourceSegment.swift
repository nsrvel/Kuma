import SwiftUI

public enum KumaDualSourceMode: String, CaseIterable, Identifiable, Hashable {
    case chooseFile
    case pasteYAML

    public var id: String { rawValue }
}

public struct KumaDualSourceSegment: View {
    @Binding public var mode: KumaDualSourceMode
    public var fileLabel: String
    public var pasteLabel: String

    public init(
        mode: Binding<KumaDualSourceMode>,
        fileLabel: String = "Choose File",
        pasteLabel: String = "Paste YAML"
    ) {
        self._mode = mode
        self.fileLabel = fileLabel
        self.pasteLabel = pasteLabel
    }

    public var body: some View {
        KumaFormSegmentBar(
            options: KumaDualSourceMode.allCases,
            selection: $mode,
            title: { option in
                switch option {
                case .chooseFile: return fileLabel
                case .pasteYAML: return pasteLabel
                }
            },
            accessibilityLabel: "Content source"
        )
    }
}

#Preview {
    struct Wrapper: View {
        @State private var mode = KumaDualSourceMode.chooseFile
        var body: some View {
            KumaDualSourceSegment(mode: $mode)
                .padding()
                .frame(width: 420)
                .background(KumaColors.canvasBackground)
        }
    }
    return Wrapper()
}
