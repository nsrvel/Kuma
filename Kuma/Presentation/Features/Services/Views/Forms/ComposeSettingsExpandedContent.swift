import SwiftUI
import UniformTypeIdentifiers

struct ComposeSettingsExpandedContent: View {
    @Binding var sourceMode: KumaDualSourceMode
    @Binding var draftPath: String
    @Binding var draftYAML: String
    let composeFilePlaceholder: String
    let editorPlaceholder: String

    var body: some View {
        KumaDualSourceSegment(mode: $sourceMode)

        if sourceMode == .chooseFile {
            KumaFilePickerField(
                label: "",
                path: $draftPath,
                placeholder: composeFilePlaceholder,
                chooseFiles: true,
                chooseDirectories: false,
                allowedContentTypes: ComposeSettingsView.composeFileTypes
            )
        } else {
            KumaCodeEditor(
                code: $draftYAML,
                placeholder: editorPlaceholder,
                minHeight: 160
            )
        }
    }
}

#Preview {
    struct Wrapper: View {
        @State private var mode = KumaDualSourceMode.chooseFile
        @State private var path = ""
        @State private var yaml = "services:\n  web:\n    image: nginx"
        var body: some View {
            ComposeSettingsExpandedContent(
                sourceMode: $mode,
                draftPath: $path,
                draftYAML: $yaml,
                composeFilePlaceholder: "~/path/to/docker-compose.yml",
                editorPlaceholder: "services:"
            )
            .padding()
            .frame(width: 420)
        }
    }
    return Wrapper()
}
